class BenefitGroupAssignment
  include Mongoid::Document
  include Mongoid::Timestamps
  include AASM

  RENEWING = %w(coverage_renewing)

  embedded_in :census_employee

  field :benefit_group_id, type: BSON::ObjectId
  field :benefit_package_id, type: BSON::ObjectId # Engine Benefit Package


  # Represents the most recent completed enrollment
  field :hbx_enrollment_id, type: BSON::ObjectId

  field :start_on, type: Date
  field :end_on, type: Date

  field :coverage_end_on, type: Date # Deprecate
  field :aasm_state, type: String, default: "initialized"
  field :is_active, type: Mongoid::Boolean #, default: true

  field :activated_at, type: DateTime

  embeds_many :workflow_state_transitions, as: :transitional

  validates_presence_of :start_on
  validates_presence_of :benefit_group_id, :if => Proc.new {|obj| obj.benefit_package_id.blank? }
  validates_presence_of :benefit_package_id, :if => Proc.new {|obj| obj.benefit_group_id.blank? }
  validate :date_guards, :model_integrity

  scope :renewing,       -> { any_in(aasm_state: RENEWING) }
  # scope :active,         -> { where(:is_active => true) }
  scope :effective_on,   ->(effective_date) { where(:start_on => effective_date) }

  scope :cover_date, lambda { |compare_date|
    result = where(
      {
        :$or => [
          {:start_on.lte => compare_date, :end_on.gte => compare_date},
          {:start_on.lte => compare_date, :end_on => nil}
        ]
      }
    ).order(start_on: :desc)
    if result.empty?
      result = where(
        {
          :$and => [
            {:start_on.lte => compare_date, :end_on => nil},
            {:start_on.gte => (compare_date == compare_date.end_of_month ? (compare_date - 1.year + 1.day) : (compare_date - 1.year))}
          ]
        }
      ).order(start_on: :desc)
    end

    # we need to deal with multiples returned
    #   1) canceled benefit group assignments
    #   2) multiple draft applications
    if result.size > 1
      date_matched = result.and(start_on: compare_date)
      if date_matched.any?
        date_matched.and(is_active: true).any? ? date_matched.and(is_active: true) : date_matched
      else
        result.where(:end_on => {:exists => true}).any? ? result.where(:end_on => {:exists => true}) : result
      end
    else
      result
    end
  }

  scope :by_benefit_package,     ->(benefit_package) { where(:benefit_package_id => benefit_package.id) }
  scope :by_benefit_package_and_assignment_on,->(benefit_package, effective_on) {
    where(:start_on.lte => effective_on, :end_on.gte => effective_on, :benefit_package_id => benefit_package.id)
  }

  class << self

    def find(id)
      ee = CensusEmployee.where(:"benefit_group_assignments._id" => id).first
      ee.benefit_group_assignments.detect { |bga| bga._id == id } unless ee.blank?
    end

    def on_date(census_employee, date)
      assignments = census_employee.benefit_group_assignments.select{ |bga| bga.created_at.present? && bga.start_on.present? && !bga.canceled? }
      assignments_with_no_end_on, assignments_with_end_on = assignments.partition { |bga| bga.end_on.nil? }

      if assignments_with_end_on.present?
        filter_assignments_with_end_on(assignments_with_end_on, assignments_with_no_end_on, date)
      elsif assignments_with_no_end_on.present?
        filter_assignments_with_no_end_on(assignments_with_no_end_on, date)
      end
    end

    def filter_assignments_with_end_on(assignments_with_end_on, assignments_with_no_end_on, date)
      perspective_assignments_with_end_on = assignments_with_end_on.select { |assignment| assignment.start_on && assignment.start_on > date }
      valid_assignments_with_end_on = assignments_with_end_on.select { |assignment| assignment.start_on && (assignment.start_on..assignment.end_on).cover?(date) }
      if valid_assignments_with_end_on.present?
        valid_assignments_with_end_on.select { |assignment| assignment.end_on.to_date > date.to_date  }.max_by(&:created_at) ||
          valid_assignments_with_end_on.last
      elsif assignments_with_no_end_on.present?
        filter_assignments_with_no_end_on(assignments_with_no_end_on, date)
      else
        bg_assignment = perspective_assignments_with_end_on.detect{ |assignment| assignment.start_on && (assignment.start_on..assignment.end_on).cover?(date) }
        bg_assignment || perspective_assignments_with_end_on.last
      end
    end

    def filter_assignments_with_no_end_on(assignments, date)
      valid_assignments_with_no_end_on = no_end_on(assignments, date)
      perspective_assignments = assignments.select do |assignment|
        next if assignment.blank? || date.blank?

        assignment.start_on && assignment.start_on > date
      end || []
      assignment =
        if valid_assignments_with_no_end_on.size > 1
          valid_assignments_with_no_end_on.select(&:is_active?).max_by(&:start_on) || valid_assignments_with_no_end_on.min_by { |valid_assignment| (valid_assignment.start_on.to_time - date.to_time).abs }
        else
          valid_assignments_with_no_end_on.first
        end
      assignment.present? ? assignment : perspective_assignments&.max_by(&:created_at)
    end

    def no_end_on(assignments, date)
      assignments.select { |assignment| (assignment.start_on..(assignment.benefit_package&.end_on || assignment.start_on.next_year.prev_day)).cover?(date) }
    end

    def by_benefit_group_id(bg_id)
      census_employees = CensusEmployee.where({:"benefit_group_assignments.benefit_group_id" => bg_id})
      census_employees.flat_map(&:benefit_group_assignments).select do |bga|
        bga.benefit_group_id == bg_id
      end
    end

    def new_from_group_and_census_employee(benefit_group, census_ee)
      census_ee.benefit_group_assignments.new(
        benefit_group_id: benefit_group._id,
        start_on: [benefit_group.start_on, census_ee.hired_on].compact.max
      )
    end
  end

  def is_case_old?
    self.benefit_package_id.blank?
  end

  def plan_year
    warn "[Deprecated] Instead use benefit application" unless Rails.env.test?
    return benefit_group.plan_year if is_case_old?
    benefit_application
  end

  def benefit_application
    benefit_package.benefit_application if benefit_package.present?
  end

  def is_application_active?
    benefit_application&.active?
  end

  def belongs_to_offexchange_planyear?
    employer_profile = plan_year.employer_profile
    employer_profile.is_conversion? && plan_year.is_conversion
  end

  def benefit_group=(new_benefit_group)
    warn "[Deprecated] Instead use benefit_package=" unless Rails.env.test?
    if new_benefit_group.is_a?(BenefitGroup)
      self.benefit_group_id = new_benefit_group._id
      return @benefit_group = new_benefit_group
    end
    self.benefit_package=(new_benefit_group)
  end

  def benefit_group
    return @benefit_group if defined? @benefit_group
    warn "[Deprecated] Instead use benefit_package" unless Rails.env.test?
    if is_case_old?
      return @benefit_group = BenefitGroup.find(self.benefit_group_id)
    end
    benefit_package
  end

  def benefit_package=(new_benefit_package)
    raise ArgumentError.new("expected BenefitPackage") unless new_benefit_package.is_a? BenefitSponsors::BenefitPackages::BenefitPackage
    self.benefit_package_id = new_benefit_package._id
    @benefit_package = new_benefit_package
  end

  def benefit_package
    return if benefit_package_id.nil?
    return @benefit_package if defined? @benefit_package
    @benefit_package = BenefitSponsors::BenefitPackages::BenefitPackage.find(benefit_package_id)
  end

  def hbx_enrollment=(new_hbx_enrollment)
    raise ArgumentError.new("expected HbxEnrollment") unless new_hbx_enrollment.is_a? HbxEnrollment
    self.hbx_enrollment_id = new_hbx_enrollment._id
    @hbx_enrollment = new_hbx_enrollment
  end

  def covered_families
    Family.where(
      {
        "households.hbx_enrollments" => {
          :"$elemMatch" => {
            :"$or" => [
              { :employee_role_id => employee_role_id },
              { :benefit_group_assignment_id => BSON::ObjectId.from_string(id) }
            ]
          }
        }
      }
    )
  end

  def employee_role_id
    id = census_employee&.employee_role_id
    BSON::ObjectId.from_string(id) if id
  end

  def hbx_enrollments
    covered_families.inject([]) do |enrollments, family|
      family.households.each do |household|
        enrollments += household.hbx_enrollments.show_enrollments_sans_canceled.select do |enrollment|
          enrollment.benefit_group_assignment_id == id || enrollment.sponsored_benefit_package_id == benefit_package_id
        end.to_a
      end
      enrollments
    end
  end

  # Deprecated
  def latest_hbx_enrollments_for_cobra
    families = Family.where({
      "households.hbx_enrollments.benefit_group_assignment_id" => BSON::ObjectId.from_string(self.id)
      })

    hbx_enrollments = families.inject([]) do |enrollments, family|
      family.households.each do |household|
        enrollments += household.hbx_enrollments.enrollments_for_cobra.select do |enrollment|
          enrollment.benefit_group_assignment_id == self.id
        end.to_a
      end
      enrollments
    end

    if census_employee.cobra_begin_date.present?
      coverage_terminated_on = census_employee.cobra_begin_date.prev_day
      hbx_enrollments = hbx_enrollments.select do |e|
        e.effective_on < census_employee.cobra_begin_date && (e.terminated_on.blank? || e.terminated_on == coverage_terminated_on)
      end
    end

    health_hbx = hbx_enrollments.detect{ |hbx| hbx.coverage_kind == 'health' && !hbx.is_cobra_status? }
    dental_hbx = hbx_enrollments.detect{ |hbx| hbx.coverage_kind == 'dental' && !hbx.is_cobra_status? }

    [health_hbx, dental_hbx].compact
  end

  def active_and_waived_enrollments
    covered_families.inject([]) do |enrollments, family|
      family.households.each do |household|
        enrollments += household.hbx_enrollments.non_expired_and_non_terminated.select { |enrollment| enrollment.benefit_group_assignment_id == self.id }
      end
      enrollments
    end
  end

  def active_enrollments
    covered_families.inject([]) do |enrollments, family|
      family.households.each do |household|
        enrollments += household.hbx_enrollments.enrolled_and_renewal.select { |enrollment| enrollment.benefit_group_assignment_id == self.id }
      end
      enrollments
    end
  end

  def covered_families_with_benefit_assignemnt
    Family.where(
      {
        "households.hbx_enrollments" => {
          :"$elemMatch" => {
            :"$and" => [
              { :employee_role_id => employee_role_id },
              { :benefit_group_assignment_id => BSON::ObjectId.from_string(id) }
            ]
          }
        }
      }
    )
  end

  def hbx_enrollment
    return @hbx_enrollment if defined? @hbx_enrollment

    if hbx_enrollment_id.blank?
      families = Family.where(
        {
          "households.hbx_enrollments.benefit_group_assignment_id" => BSON::ObjectId.from_string(id)
        }
      )

      families.each do |family|
        family.households.each do |household|
          household.hbx_enrollments.show_enrollments_sans_canceled.each do |enrollment|
            @hbx_enrollment = enrollment if enrollment.benefit_group_assignment_id == id
          end
        end
      end

      @hbx_enrollment
    else
      @hbx_enrollment = HbxEnrollment.find(hbx_enrollment_id)
    end
  end

  # def hbx_enrollment
  #   @hbx_enrollment ||= HbxEnrollment.where(id: hbx_enrollment_id) || hbx_enrollments.max_by(&:created_at)
  # end

  def end_benefit(end_date)
    update_attributes!(end_on: end_date)
  end

  def end_date=(end_date)
    end_date = [start_on, end_date].max
    self[:end_on] = benefit_package.cover?(end_date) ? end_date : benefit_end_date
  end

  def benefit_end_date
    end_on || benefit_package.end_on
  end

  def is_belong_to?(new_benefit_package)
    benefit_package == new_benefit_package
  end

  def canceled?
    return false if end_on.blank?

    start_on == end_on
  end

  def update_status_from_enrollment(hbx_enrollment)
    if hbx_enrollment.coverage_kind == 'health'
      if HbxEnrollment::ENROLLED_STATUSES.include?(hbx_enrollment.aasm_state)
        change_state_without_event(:coverage_selected)
      end

      if HbxEnrollment::RENEWAL_STATUSES.include?(hbx_enrollment.aasm_state)
        change_state_without_event(:coverage_renewing)
      end

      if HbxEnrollment::WAIVED_STATUSES.include?(hbx_enrollment.aasm_state)
        change_state_without_event(:coverage_waived)
      end
    end
  end

  def change_state_without_event(new_state)
    old_state = self.aasm_state
    self.update(aasm_state: new_state.to_s)
    self.workflow_state_transitions.create(from_state: old_state, to_state: new_state)
  end

  aasm do
    state :initialized, initial: true
    state :coverage_selected
    state :coverage_waived
    state :coverage_terminated
    state :coverage_void
    state :coverage_renewing
    state :coverage_expired

    #FIXME create new hbx_enrollment need to create a new benefitgroup_assignment
    #then we will not need from coverage_terminated to coverage_selected
    event :select_coverage, :after => :record_transition do
      transitions from: [:initialized, :coverage_waived, :coverage_terminated, :coverage_renewing], to: :coverage_selected
    end

    event :waive_coverage, :after => :record_transition do
      transitions from: [:initialized, :coverage_selected, :coverage_renewing], to: :coverage_waived
    end

    event :renew_coverage, :after => :record_transition do
      transitions from: :initialized, to: :coverage_renewing
    end

    event :terminate_coverage, :after => :record_transition do
      transitions from: :initialized, to: :coverage_void
      transitions from: :coverage_selected, to: :coverage_terminated
      transitions from: :coverage_renewing, to: :coverage_terminated
    end

    event :expire_coverage, :after => :record_transition do
      transitions from: [:coverage_selected, :coverage_renewing], to: :coverage_expired, :guard  => :can_be_expired?
    end

    event :delink_coverage, :after => :record_transition do
      transitions from: [:coverage_selected, :coverage_waived, :coverage_terminated, :coverage_void, :coverage_renewing, :coverage_waived], to: :initialized, after: :propogate_delink
    end
  end


  def waive_benefit(date = TimeKeeper.date_of_record)
    make_active(date)
  end

  def begin_benefit(date = TimeKeeper.date_of_record)
    make_active(date)
  end

  # def is_active
  #   is_active?
  # end

  def is_active?(date = TimeKeeper.date_of_record)
    return false if start_on.blank? || canceled?

    end_date = end_on || start_on.next_year.prev_day
    (start_on..end_date).cover?(date)
  end

  def make_active
    census_employee.benefit_group_assignments.where(:id.ne => id).inject([]) do |_dummy, benefit_group_assignment|
      end_on = benefit_group_assignment.end_on || (start_on - 1.day)
      if is_case_old?
        benefit_group_assignment.plan_year.end_on unless benefit_group_assignment.plan_year.coverage_period_contains?(end_on)
      else
        benefit_group_assignment.benefit_application.end_on unless benefit_group_assignment.benefit_application.effective_period.cover?(end_on)
      end
    end
    # TODO: Hack to get census employee spec to pass
    #bga_to_activate = census_employee.benefit_group_assignments.select { |bga| HbxEnrollment::ENROLLED_STATUSES.include?(bga.hbx_enrollment&.aasm_state) }.last
    #if bga_to_activate.present?
    # bga_to_activate.update_attributes!(activated_at: TimeKeeper.datetime_of_record)
    #else
    # TODO: Not sure why this isn't working right
    update_attributes!(activated_at: TimeKeeper.datetime_of_record)
    #end
  end

  def renew_employee_enrollments

  end

  private

  def can_be_expired?
    benefit_group.end_on <= TimeKeeper.date_of_record
  end

  def record_transition
    self.workflow_state_transitions << WorkflowStateTransition.new(
      from_state: aasm.from_state,
      to_state: aasm.to_state,
      event: aasm.current_event
    )
  end

  def propogate_delink
    if hbx_enrollment.present?
      hbx_enrollment.terminate_coverage! if hbx_enrollment.may_terminate_coverage?
    end
    # self.hbx_enrollment_id = nil
  end

  def model_integrity
    self.errors.add(:benefit_group, "benefit_group required") unless benefit_group.present?

    # TODO: Not sure if this can really exist if we depracate aasm_state from here. Previously the hbx_enrollment was checked if coverage_selected?
    # which references the aasm_state, but if thats depracated, not sure hbx_enrollment can be checked any longer. CensusEmployee model has an instance method
    # called create_benefit_package_assignment(new_benefit_package, start_on) which creates a BGA without hbx enrollment.
    # self.errors.add(:hbx_enrollment, "hbx_enrollment required") if hbx_enrollment.blank?
    if hbx_enrollment.present?
      self.errors.add(:hbx_enrollment, "benefit group missmatch") unless hbx_enrollment.sponsored_benefit_package_id == benefit_package_id
      # TODO: Re-enable this after enrollment propagation issues resolved.
      #       Right now this is causing issues when linking census employee under Enrollment Factory.
      # self.errors.add(:hbx_enrollment, "employee_role missmatch") if hbx_enrollment.employee_role_id != census_employee.employee_role_id and census_employee.employee_role_linked?
    end
  end

  def date_guards
    return if benefit_group.blank? || start_on.blank?

    effective_period = benefit_group.plan_year.start_on..benefit_group.plan_year.end_on
    errors.add(:start_on, "can't occur outside plan year dates") unless effective_period.cover?(start_on)
    if end_on.present?
      errors.add(:end_on, "can't occur outside plan year dates") unless effective_period.cover?(end_on)
      errors.add(:end_on, "can't occur before start date") if end_on < start_on
    end
  end
end
