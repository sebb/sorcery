require 'rotp'
module Sorcery
  module Model
    module Submodules
      # This submodule
      # This is the model part of the submodule, which provides configuration options.
      module TwoFactor
        def self.included(base)
          base.sorcery_config.class_eval do
            attr_accessor :two_factor_secret_attribute_name,   # two factor secret attribute name.
                          :two_factor_password_attribute_name, #
                          :two_factor_allowed_drift            # accept OTP from the previous interval

          end
          base.sorcery_config.instance_eval do
            @defaults.merge!(:@two_factor_secret_attribute_name   => :two_factor_secret,
                             :@two_factor_password_attribute_name => :one_time_password,
                             :@two_factor_allowed_drift           => false)
            reset!
          end

          base.sorcery_config.before_authenticate << :prevent_login_without_second_factor

          if defined?(Mongoid) and base.ancestors.include?(Mongoid::Document)
            base.sorcery_config.after_config << :define_two_factor_mongoid_fields
          end
          if defined?(MongoMapper) and base.ancestors.include?(MongoMapper::Document)
            base.sorcery_config.after_config << :define_two_factor_mongo_mapper_fields
          end

          base.class_eval do
            attr_accessor :current_device_token, :one_time_password

          end
          base.send(:include, InstanceMethods)
          base.extend(ClassMethods)
        end

        module ClassMethods

          # Override.
          def authenticate_with_two_factor(credentials = {})
            raise ArgumentError, "at least 2 arguments required" if credentials.size < 2
            credentials[:login].downcase! if @sorcery_config.downcase_username_before_authenticating
            user = find_by_credentials([credentials[:login]])

            set_encryption_attributes()

            if user
              user.one_time_password    = credentials[:one_time_password]
              user.current_device_token = credentials[:trusted_device_token]
            end
            _salt = user.send(@sorcery_config.salt_attribute_name) if user && !@sorcery_config.salt_attribute_name.nil? && !@sorcery_config.encryption_provider.nil?
            user if user && @sorcery_config.before_authenticate.all? { |c| user.send(c) } && credentials_match?(user.send(@sorcery_config.crypted_password_attribute_name), credentials[:password], _salt)
          end

          protected

          def define_two_factor_mongoid_fields
            field sorcery_config.two_factor_secret_attribute_name, :type => String
          end

          def define_two_factor_mongo_mapper_fields
            key sorcery_config.two_factor_secret_attribute_name, String
          end
        end

        module InstanceMethods

          def verify_one_time_password(one_time_password, time = Time.now)
            config = sorcery_config
            secret = self.send(config.two_factor_secret_attribute_name)
            return true if secret.nil?

            totp = ROTP::TOTP.new(secret)
            if config.two_factor_allowed_drift
              totp.verify_with_drift(one_time_password, config.two_factor_allowed_drift, time)
            else
              totp.verify(one_time_password, time)
            end
          end

          def enable_two_factor!(secret = nil)
            config = sorcery_config
            secret ||= ROTP::Base32.random_base32
            self.update_many_attributes(config.two_factor_secret_attribute_name => secret)
          end

          def disable_two_factor!
            config = sorcery_config
            self.update_many_attributes(config.two_factor_secret_attribute_name => nil)
          end

          # This doesn't really belong in the model, a decorator or a helper would be better
          def two_factor_provisioning_uri(name)
            secret = self.send(sorcery_config.two_factor_secret_attribute_name)
            return nil if secret.nil?

            totp = ROTP::TOTP.new(secret)
            totp.provisioning_uri(name)
          end

          def trusted_device_token
            secret = self.send(sorcery_config.two_factor_secret_attribute_name)
            return nil if secret.nil?

            totp = ROTP::TOTP.new(secret)
            totp.at(0)
          end

          def verify_trusted_device_token(password)
            verify_one_time_password(password, 0)
          end

          def has_two_factor_enabled?
            secret = self.send(sorcery_config.two_factor_secret_attribute_name)
            !secret.nil?
          end

          def prevent_login_without_second_factor
            return true unless has_two_factor_enabled?
            verify_trusted_device_token(@current_device_token) || verify_one_time_password(@one_time_password)
          end
        end
      end
    end
  end
end
