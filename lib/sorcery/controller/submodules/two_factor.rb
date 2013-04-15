module Sorcery
  module Controller
    module Submodules
      # This module implements 2 factor authentication
      # See Sorcery::Model::Submodules::TwoFactor for configuration options.
      module TwoFactor
        def self.included(base)
          base.send(:include, InstanceMethods)

          Config.after_failed_login << :untrust_this_device!
          Config.before_logout << :untrust_this_device!
        end

        module InstanceMethods

          # Override regular login method in order to set the one time password
          def login_with_two_factor(credentials = {})
            @current_user                      = nil
            credentials[:trusted_device_token] = cookies.signed[:trusted_device_token]
            credentials_array                  = [credentials[:login], credentials[:password], credentials[:remember]]
            user                               = user_class.authenticate_with_two_factor(credentials)
            if user
              old_session = session.dup.to_hash
              reset_session # protect from session fixation attacks
              old_session.each_pair do |k, v|
                session[k.to_sym] = v
              end
              form_authenticity_token

              auto_login(user)
              after_login!(user, credentials_array)
              current_user
            else
              after_failed_login!(credentials_array)
              nil
            end
          end

          # Check if the current device is trusted or requires a OTP to be passed
          def trusted_device?
            current_user.verify_trusted_device_token(cookies.signed[:trusted_device_token])
          end

          # Trust a cookie by dropping a signed cookie
          def trust_this_device!
            cookies.signed[:trusted_device_token] = {
                :value    => current_user.trusted_device_token,
                :expires  => 30.days.from_now,
                :httponly => true,
                :domain   => Config.cookie_domain
            }
          end

          # Delete the trusted device cookie
          def untrust_this_device!(user)
            cookies.delete(:trusted_device_token, :domain => Config.cookie_domain)
          end

        end
      end
    end
  end
end
