class MigrationTask < Rake::Task
  def initialize(task_name, app)
    super(task_name, app)
    task = task_name.to_s.match(/\:?(\w+)$/)[1]
    @actions << proc { self.send(task) }
  end

  def self.define_task(*args, &blk)
    Rake.application.define_task(self, *args, &blk)
  end
end
