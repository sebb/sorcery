shared_examples_for "rails_3_two_factor_model" do
  # ----------------- PLUGIN CONFIGURATION -----------------------
  describe User, "loaded plugin configuration" do

    before(:all) do
      sorcery_reload!([:two_factor])
    end

    after(:each) do
      User.sorcery_config.reset!
    end

    it "should enable configuration option 'two_factor_secret_attribute_name'" do
      sorcery_model_property_set(:two_factor_secret_attribute_name, :my_secret)
      User.sorcery_config.two_factor_secret_attribute_name.should equal(:my_secret)
    end

    it "should enable configuration option 'two_factor_password_attribute_name'" do
      sorcery_model_property_set(:two_factor_password_attribute_name, :an_other_password)
      User.sorcery_config.two_factor_password_attribute_name.should equal(:an_other_password)
    end

    it "should enable configuration option 'two_factor_allowed_drift'" do
      sorcery_model_property_set(:two_factor_allowed_drift, 42)
      User.sorcery_config.two_factor_allowed_drift.should equal(42)
    end
  end

  # ----------------- PLUGIN ACTIVATED -----------------------
  describe User, "when activated with sorcery" do

    before(:all) do
      sorcery_reload!([:two_factor])
    end

    before(:each) do
      create_new_user
      @now = Time.utc(2013, 1, 1)
    end

    before(:each) do
      User.delete_all
    end


    specify { @user.should respond_to(:two_factor_secret) }
    specify { @user.should respond_to(:verify_one_time_password) }
    specify { @user.should respond_to(:enable_two_factor!) }
    specify { @user.should respond_to(:disable_two_factor!) }
    specify { @user.should respond_to(:two_factor_provisioning_uri) }
    specify { @user.should respond_to(:trusted_device_token) }
    specify { @user.should respond_to(:verify_trusted_device_token) }
    specify { @user.should respond_to(:has_two_factor_enabled?) }
    specify { @user.should respond_to(:prevent_login_without_second_factor) }

    context "user has two factor auth disabled" do

      before(:each) do
        @user.disable_two_factor!
      end

      it "should not prevent a user from logging in if he doesn't have 2 factor auth enabled" do
        @user.verify_one_time_password(123456, Time.now).should be_true
      end

      it "should not return a provisioning uri" do
        @user.two_factor_provisioning_uri('My great app').should be_nil
      end

      it "has_two_factor_enabled? should return false" do
        @user.has_two_factor_enabled?.should be_false
      end
    end

    context "user has two factor auth enabled" do

      before(:each) do
        @user.enable_two_factor!('a' * 12)
      end

      context "drift is NOT enabled" do
        it "should accept a valid password" do
          @user.verify_one_time_password(22814, @now).should be_true
        end
        it "should not accept an expired password" do
          @user.verify_one_time_password(22814, @now + 30).should be_false
        end
      end

      context "drift is enabled" do
        it "should accept a valid password" do
          sorcery_model_property_set(:two_factor_allowed_drift, 30)
          @user.verify_one_time_password(22814, @now).should be_true
        end

        it "should accept an expired password within the allowed drift" do
          sorcery_model_property_set(:two_factor_allowed_drift, 30)
          @user.verify_one_time_password(22814, @now + 15).should be_true
        end

        it "should not accept an expired password outside the allowed drift" do
          sorcery_model_property_set(:two_factor_allowed_drift, 30)
          @user.verify_one_time_password(22814, @now + 60).should be_false
        end
      end

      it "should return a provisioning uri" do
        @user.two_factor_provisioning_uri('My great app').should_not be_nil
      end

      it "should return a provisioning uri with the shared secret" do
        (@user.two_factor_provisioning_uri('My great app').include?(@user.two_factor_secret)).should be_true
      end

      it "should return a valid trusted device token" do
        @user.verify_trusted_device_token(@user.trusted_device_token).should be_true
      end

      it "has_two_factor_enabled? should return true" do
        @user.has_two_factor_enabled?.should be_true
      end
    end
  end
end
