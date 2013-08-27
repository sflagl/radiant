require 'spec_helper'

describe User, "validations" do
  dataset :users
  test_helper :validations

  before :each do
    @model = @user = User.new(user_params)
  end

  describe 'name' do

    let(:user){ User.new(user_params) }

    it 'is invalid when longer than 100 characters' do
      user.name = 'x' * 101
      expect(user.errors_on(:name)).to include('this must not be longer than 100 characters')
    end

    it 'is invalid when blank' do
      user.name = ''
      expect(user.errors_on(:name)).to include("this must not be blank")
    end

    it 'is valid when 100 characters or shorter' do
      user.name = 'x' * 100
      expect(user.errors).to be_blank
    end

  end

  describe 'email' do

    let(:user){ User.new(user_params) }

    it 'is invalid when longer than 255 characters' do
      user.email = ('x' * 247) + '@test.com'
      expect(user.errors_on(:email)).to include('this must not be longer than 255 characters')
    end

    it 'is valid when blank' do
      user.email = nil
      expect(user).to have(0).errors_on(:email)
    end

    it 'is valid when 100 characters or shorter' do
      user.name = ('x' * 246) + '@test.com'
      expect(user.errors_on(:email)).to be_blank
    end

    it 'is invalid when in the incorrect format' do
      ['@test.com', 'test@', 'testtest.com', 'test@test', 'test me@test.com', 'test@me.c'].each do |address|
        user.email = address
        expect(user.errors_on(:email)).to include('this is not a valid e-mail address')
      end
    end

  end

  describe 'login' do

    let(:user){ User.new(user_params) }

    it 'is invalid when longer than 40 characters' do
      user.login = 'x' * 41
      expect(user).to have(1).error_on(:login)
    end

    it 'is valid when blank' do
      user.login = nil
      expect(user).to have(0).errors_on(:login)
    end

    it 'is invalid when shorter than 3 characters' do
      user.login = 'xx'
      expect(user).to have(1).error_on(:login)
    end

    it 'is valid when 40 characters or shorter' do
      user.login = 'x' * 40
      expect(user).to have(0).errors_on(:login)
    end
  end

  describe 'password' do

    let(:user){ User.new(user_params) }

    it 'is invalid when longer than 40 characters' do
      user.password = 'x' * 41
      expect(user.errors_on(:password)).to include('this must not be longer than 40 characters')
    end

    it 'is invalid when shorter than 5 characters' do
      user.password = 'x' * 4
      expect(user.errors_on(:password)).to include('this must be at least 5 characters long')
    end

    it 'is valid when 40 characters or shorter' do
      user.password = 'x' * 40
      expect(user).to have(0).errors_on(:password)
    end

    it 'ensures the confirmation matches' do
      user.password = 'test'
      user.password_confirmation = 'not correct'
      expect(user.errors_on(:password)).to include('this must match confirmation')
    end
  end


  describe "self.unprotected_attributes" do
    it "should be an array of [:name, :email, :login, :password, :password_confirmation, :locale]" do
      # Make sure we clean up after anything set in another spec
      User.instance_variable_set(:@unprotected_attributes, nil)
      User.unprotected_attributes.should == [:name, :email, :login, :password, :password_confirmation, :locale]
    end
  end
  describe "self.unprotected_attributes=" do
    it "should set the @@unprotected_attributes variable to the given array" do
      User.unprotected_attributes = [:password, :email, :other]
      User.unprotected_attributes.should == [:password, :email, :other]
    end
  end

  it 'should validate uniqueness' do
    assert_invalid :login, 'this login is already in use', 'existing'
  end

  it 'should validate format' do
    assert_invalid :email, 'this is not a valid e-mail address', '@test.com', 'test@', 'testtest.com',
      'test@test', 'test me@test.com', 'test@me.c'
    assert_valid :email, '', 'test@test.com'
  end
end

describe User do
  dataset :users

  before :each do
    @user = User.new(user_params)
  end

  it 'should confirm the password by default' do
    @user = User.new
  end

  it 'should save password encrypted' do
    @user.password_confirmation = @user.password = 'test_password'
    @user.save!
    @user.password.should == @user.sha1('test_password')
  end

  it 'should save existing but empty password' do
    @user.save!
    @user.password_confirmation = @user.password = ''
    @user.save!
    @user.password.should == @user.sha1('password')
  end

  it 'should save existing but different password' do
    @user.save!
    @user.password_confirmation = @user.password = 'cool beans'
    @user.save!
    @user.password.should == @user.sha1('cool beans')
  end

  it 'should save existing but same password' do
    @user.save! && @user.save!
    @user.password.should == @user.sha1('password')
  end

  it "should create a salt when encrypting the password" do
    @user.salt.should be_nil
    @user.send(:encrypt_password)
    @user.salt.should_not be_nil
    @user.password.should == @user.sha1('password')
  end

  describe ".remember_me" do
    before do
      Radiant::Config.stub!(:[]).with('session_timeout').and_return(2.weeks)
      @user.save
      @user.remember_me
      @user.reload
    end

    it "should remember user" do
      @user.session_token.should_not be_nil
    end
  end

  describe ".forget_me" do

    before do
      Radiant::Config.stub!(:[]).with('session_timeout').and_return(2.weeks)
      @user.save
      @user.remember_me
    end

    it "should forget user" do
      @user.forget_me
      @user.session_token.should be_nil
    end
  end

end

describe User, "class methods" do
  dataset :users

  it 'should authenticate with correct username and password' do
    expected = users(:existing)
    user = User.authenticate('existing', 'password')
    user.should == expected
  end

  it 'should authenticate with correct email and password' do
    expected = users(:existing)
    user = User.authenticate('existing@example.com', 'password')
    user.should == expected
  end

  it 'should not authenticate with bad password' do
    User.authenticate('existing', 'bad password').should be_nil
  end

  it 'should not authenticate with bad user' do
    User.authenticate('nonexisting', 'password').should be_nil
  end
end

describe User, "roles" do
  dataset :users

  it "should not have a non-existent role" do
    users(:existing).has_role?(:foo).should be_false
  end

  it "should not have a role for which the corresponding method returns false" do
    users(:existing).has_role?(:designer).should be_false
    users(:existing).has_role?(:admin).should be_false
  end

  it "should have a role for which the corresponding method returns true" do
    users(:designer).has_role?(:designer).should be_true
    users(:admin).has_role?(:admin).should be_true
  end
end