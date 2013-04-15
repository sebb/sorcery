require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe ApplicationController do

  before(:all) do
    ActiveRecord::Migrator.migrate("#{Rails.root}/db/migrate/two_factor")
  end

  after(:all) do
    ActiveRecord::Migrator.rollback("#{Rails.root}/db/migrate/two_factor")
  end

  # ----------------- TWO FACTOR AUTH -----------------------
  describe ApplicationController, "with two factor features" do

    before(:all) do
      sorcery_reload!([:two_factor])
    end

    after(:each) do
      session = nil
      cookies = nil
      User.delete_all
    end

    after(:all) do
      sorcery_reload!
    end


    context "user has two factor auth disabled" do

      before(:each) do
        create_new_user
      end

      it "should not prevent a user from logging in if he doesn't have 2 factor auth enabled" do
        get :test_login_with_two_factor, :username => 'gizmo', :password => 'secret'
        assigns[:user].should == @user
        session[:user_id].should == @user.id
      end

    end

    context "user has two factor auth enabled" do

      before(:each) do
        create_new_user
        @user.enable_two_factor!('a' * 12)
      end

      after(:each) do
        User.delete_all
      end

      specify { should respond_to(:login_with_two_factor) }
      specify { subject.should respond_to(:trust_this_device!) }
      specify { subject.should respond_to(:untrust_this_device!) }

      it "should not accept login without the 2nd factor" do
        get :test_login_with_two_factor, :username => 'gizmo', :password => 'secret'
        assigns[:user].should be_nil
        session[:user_id].should be_nil
      end

      it "should not accept login with an invalid 2nd factor" do
        get :test_login_with_two_factor, :username => 'gizmo', :password => 'secret', :remember => '', :one_time_password => 123456
        assigns[:user].should be_nil
        session[:user_id].should be_nil
      end

      it "should accept login with a valid 2nd factor" do
        Timecop.travel(Time.utc(2013, 1, 1))
        get :test_login_with_two_factor, :username => 'gizmo', :password => 'secret', :remember => '', :one_time_password => 22814
        assigns[:user].should == @user
        session[:user_id].should == @user.id
      end

      it "should set cookie on trust_device!" do
        Timecop.travel(Time.utc(2013, 1, 1))
        get :test_login_with_trust_device, :username => 'gizmo', :password => 'secret', :remember => '', :one_time_password => 22814

        @request.cookies.merge!(cookies)
        cookies = ActionDispatch::Cookies::CookieJar.build(@request)
        cookies.signed[:trusted_device_token].should_not be_nil
        cookies.signed[:trusted_device_token].should == assigns[:user].trusted_device_token

      end
      it "logout should also untrust_device!" do
        session[:user_id] = @user.id
        get :test_logout_on_trusted_device
        cookies[:trusted_device_token].should be_nil
      end
    end

=begin
    it "should set cookie on trust_device!" do
      post :test_login_with_trust_device, :username => 'gizmo', :password => 'secret', :one_time_password => 22814
      @request.cookies.merge!(cookies)
      cookies = ActionDispatch::Cookies::CookieJar.build(@request)
      cookies.signed["trusted_device_token"].should be_true
    end
=end

=begin
    it "logout should also untrust_device!" do
      cookies = ActionDispatch::Cookies::CookieJar.build(@request)
      cookies.signed["trusted_device_token"] == {:value => 'asd54234dsfsd43534', :expires => 3600}
      get :test_logout
      cookies["trusted_device_token"].should be_nil
    end
=end

  end
end
