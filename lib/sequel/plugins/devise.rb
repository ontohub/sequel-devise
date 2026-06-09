module Sequel
  module Plugins
    module Devise
      def self.apply(model, options = {})
        model.extend ::Devise::Models
        model.plugin :hook_class_methods # Devise requires a before_validation
        model.plugin :dirty # email_changed?
        model.plugin :validation_class_methods # for using validatable module

        # for Devise::Models::Trackable
        model.send :alias_method, :new_record?, :new?
      end

      module InstanceMethods
        def changed? # For rememberable
          !changed_columns.empty?
        end

        def encrypted_password_changed? # For recoverable and database_authenticatable
          new? || column_changed?(:encrypted_password)
        end

        def email_changed? # For validatable
          new? || column_changed?(:email)
        end

        def email_was # For confirmable
          column_changes[:email].first
        end

        # for database_authenticatable:
        def assign_attributes(hash)
          set hash
        end

        def update_attributes(hash, *ignored)
          begin
            update(hash) != false
          rescue Sequel::ValidationFailed
            return false
          end
        end

        def update_attribute(key, value)
          update_attributes key => value
        end

        private

        def devise_safe_values
          values.delete_if{|k, v| devise_safe_keys.include?(k) || k =~ /password/i }
        end

        def devise_safe_keys
          authenticatable = ::Devise::Models::Authenticatable

          if authenticatable.const_defined?(:UNSAFE_ATTRIBUTES_FOR_SERIALIZATION)
            authenticatable::UNSAFE_ATTRIBUTES_FOR_SERIALIZATION
          else
            authenticatable::BLACKLIST_FOR_SERIALIZATION
          end
        end
      end

      module ClassMethods

        def human_attribute_name(key)
          key.to_s
        end

        def validates_length_of(*atts)
          opts = {
            nil_message:  'is not present',
            too_long:     'is too long',
            too_short:    'is too short',
            wrong_length: 'is the wrong length'
          }.merge!(extract_options!(atts))

          opts[:tag] ||= ([:length] + [:maximum, :minimum, :is, :within].reject { |x| !opts.include?(x) }).join('-').to_sym
          reflect_validation(:length, opts, atts)
          atts << opts

          validates_each(*atts) do |o, a, v|
            if opts.include?(:maximum)
              m = devise_validation_value(opts[:maximum])
              o.errors.add(a, opts[:message] || (v ? opts[:too_long] : opts[:nil_message])) unless v && v.size <= m
            end

            if opts.include?(:minimum)
              m = devise_validation_value(opts[:minimum])
              o.errors.add(a, opts[:message] || opts[:too_short]) unless v && v.size >= m
            end

            if opts.include?(:is)
              i = devise_validation_value(opts[:is])
              o.errors.add(a, opts[:message] || opts[:wrong_length]) unless v && v.size == i
            end

            if opts.include?(:within)
              w = devise_validation_value(opts[:within])
              o.errors.add(a, opts[:message] || opts[:wrong_length]) unless v && w.public_send(w.respond_to?(:cover?) ? :cover? : :include?, v.size)
            end
          end
        end

        module OverrideFixes
          def inspect(safe = true)
            return self.class.superclass.instance_method(:inspect).bind(self)[] unless safe
            "#<#{self.class} @values=#{devise_safe_values.inspect}>"
          end
        end

        def devise_modules_hook!
          yield
          include OverrideFixes
        end

        ::Sequel::Model::HOOKS.reject { |hook| hook == :after_commit }.each do |hook|
          define_method(hook) do |method = nil, options = {}, &block|
            if Symbol === (if_method = options[:if])
              orig_block = block
              block = nil
              method_without_if = method
              method = :"_sequel_#{hook}_hook_with_if_#{method}"
              define_method(method) do
                return unless send if_method
                send method_without_if
                instance_eval &orig_block if orig_block
              end
              private method
            end
            super method, &block
          end
        end

        define_method(:after_commit) do |method = nil, options = {}, &block|
          if Symbol === (if_method = options[:if])
            orig_block = block
            block = nil
            method_without_if = method
            method = :"_sequel_after_commit_hook_with_if_#{method}"
            define_method(method) do
              return unless send if_method
              send method_without_if
              instance_eval &orig_block if orig_block
            end
            private method
          end

          commit_method = :"_sequel_after_commit_hook__actual_commit_#{method}"
          define_method(commit_method) do
            db.after_commit do
              send method
              instance_eval &block if block
            end
          end
          private commit_method

          case options[:on]
          when :create
            send :after_create, commit_method
          when :update
            send :after_update, commit_method
          else
            send :after_save, commit_method
          end
        end

        private

        def devise_validation_value(value)
          value.respond_to?(:call) ? value.call : value
        end
      end
    end
  end
end
