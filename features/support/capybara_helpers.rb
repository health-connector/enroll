# frozen_string_literal: true

module CapybaraHelpers
  include L10nHelper
  include HtmlScrubberUtil

  # Perform an action then wait for the page to reload before proceeding
  def wait_for_page_reload_until(timeout, slice_size = 0.2, &blk)
    execute_script(<<-JSCODE)
      window.document['_test_waiting_for_page_reload'] = true;#{' '}
    JSCODE
    blk.call
    wait_for_condition_until(timeout, slice_size) do
      evaluate_script(<<-JSCODE)
        !(window.document['_test_waiting_for_page_reload'] == true)
      JSCODE
    end
    execute_script(<<-JSCODE)
      delete window.document['_test_waiting_for_page_reload'];
    JSCODE
  end

  # Throw a one-time load callback on datatables so we can use it to make sure
  # it has finished loading.  Useful for clicking a filter and making sure it's
  # done reloading.
  def with_datatable_load_wait(timeout, slice_size = 0.2, &blk)
    execute_script(<<-JSCODE)
      $('.effective-datatable').DataTable().one('draw.dt', function() {
        window['ef_datatables_done_loading'] = true;#{' '}
      });
    JSCODE
    blk.call
    wait_for_condition_until(timeout, slice_size) do
      evaluate_script(<<-JSCODE)
        window['ef_datatables_done_loading'] == true
      JSCODE
    end
    execute_script(<<-JSCODE)
      delete window['ef_datatables_done_loading'];
    JSCODE
  end

  def wait_for_condition_until(timeout, slice_size = 0.2, &blk)
    test_val = blk.call
    waited_time = 0
    while !test_val && (waited_time < timeout)
      sleep slice_size
      test_val = blk.call
      waited_time += slice_size
    end
  end

  def select_from_chosen(val, from:)
    chosen_input = find 'a.chosen-single'
    chosen_input.click
    chosen_results = find 'ul.chosen-results'
    within(chosen_results) do
      find('li', text: val).click
    end
  end

  def wait_for_ajax(delta = 2, time_to_sleep = 0.2)
    start_time = Time.now
    Timeout.timeout(delta) do
      sleep(0.01) until finished_all_ajax_requests?
    end
    end_time = Time.now
    raise "ajax request failed: took longer than #{delta.seconds} seconds. It waited #{end_time - start_time} seconds." if Time.now > start_time + delta.seconds

    sleep(time_to_sleep)
  end

  # TODO: Not sure this is still the most current API.
  #       Recent reading indicates it might have been swapped out for
  #       "jQuery.ajax.active".
  def finished_all_ajax_requests?
    page.evaluate_script('window.fetchQueue === undefined || window.fetchQueue?.length === 0')
  end

  def l10n(translation_key, interpolated_keys = {})
    result = fetch_translation(translation_key.to_s, interpolated_keys)
    sanitize_result(result, translation_key)
  rescue I18n::MissingTranslationData
    translation_key.gsub(/\W+/, '').titleize
  end

  def fetch_translation(translation_key, interpolated_keys)
    options = interpolated_keys.present? ? interpolated_keys.merge(default: default_translation(translation_key)) : {}
    I18n.t(translation_key, **options, raise: true)
  end

  # rubocop:disable Style/GlobalVars
  def select_session(id)
    Capybara.instance_variable_set("@session_pool", {"#{Capybara.current_driver}#{Capybara.app.object_id}" => $sessions[id]})
  end

  def in_session(id)
    $sessions ||= {}
    $sessions[:default] ||= Capybara.current_session
    $sessions[id]       ||= Capybara::Session.new(Capybara.current_driver, Capybara.app)

    select_session(id)
    yield
    select_session(:default)
  end
  # rubocop:enable Style/GlobalVars
end

World(CapybaraHelpers)
