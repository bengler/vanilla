module Vanilla

  class Configuration

    class ProviderNotFound < Exception; end

    include Singleton

    def initialize
      @stores = {}
    end

    def load!(root_path = nil)
      @stores.clear
      root_path ||= File.expand_path('../../..', __FILE__)
      Dir.glob(File.join(root_path, 'config/stores/*.yml')).each do |file_name|
        store = File.basename(file_name.gsub(/\.yml$/, ''))
        File.open(file_name) do |file|
          @stores[store] = YAML.load(file).symbolize_keys
        end
      end
    end

    attr_reader :stores

  end

end