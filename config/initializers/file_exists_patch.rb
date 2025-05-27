# frozen_string_literal: true

unless File.respond_to?(:exists?)
  class File
    def self.exists?(*)
      exist?(*)
    end
  end
end

unless Dir.respond_to?(:exists?)
  class Dir
    def self.exists?(*)
      exist?(*)
    end
  end
end