module Vanilla
  class User < ActiveRecord::Base

    belongs_to :store
    has_many :tokens,
      :foreign_key => 'user_id',
      :class_name => 'Token',
      :dependent => :destroy
    has_many :authorizatons,
      :foreign_key => 'user_id',
      :class_name => 'Authorization',
      :dependent => :destroy

    before_save :encrypt_password
    after_save :reset_password_attribute

    validates :store,
      :presence => {:message => 'store_required'}
    validates :name,
      :presence => {:message => 'name_required'}
    validates_each :name do |record, attr, value|
      if value and (store = record.store)
        if value.length < store.minimum_user_name_length
          record.errors.add(attr, 'name_is_too_short')
        elsif value.length > store.maximum_user_name_length
          record.errors.add(attr, 'name_is_too_long')
        end
        unless value =~ store.user_name_pattern
          record.errors.add(attr, 'name_contains_invalid_name_characters')
        end
      end
    end
    validates_each :password do |record, attr, value|
      # We use validates_each here to ensure that we only generate
      # a single validation error per case
      if record.send(:validate_password?)
        if value.blank?
          record.errors.add(attr, 'password_required')
        elsif value.length < 5
          record.errors.add(attr, 'password_is_too_short')
        elsif record.send(:validate_password_confirmation?) and
          normalize_password(value) != normalize_password(record.password_confirmation)
          record.errors.add(attr, 'password_confirmation_mismatch')          
        end
      end
    end
    validates_each :current_password do |record, attr, value|
      # We use validates_each here to ensure that we only generate
      # a single validation error per case
      if not record.new_record? and record.current_password and record.send(:validate_password?)
        if value.blank?
          record.errors.add(attr, 'password_required')
        elsif not record.password_match?(value)
          record.errors.add(attr, 'wrong_password')          
        end
      end
    end
    validates_each :email_address do |record, attr, value|
      if value.present?
        if not User.email_valid?(value)
          record.errors.add(attr, 'invalid_email_address')
        elsif record.active?
          conflicting_user = User.active.in_store(record.store).
            having_email(value).where(:email_verified => true).first
          if conflicting_user and conflicting_user != record
            record.errors.add(attr, 'email_address_in_use')
          end
        end
      else
        record.errors.add(attr, 'email_address_required') if record.email_required
      end
    end
    validates_each :mobile_number do |record, attr, value|
      if value.present?
        if not User.mobile_valid?(value)
          record.errors.add(attr, 'invalid_mobile_number')
        elsif record.active?
          conflicting_user = User.active.in_store(record.store).
            having_mobile(value).where(:mobile_verified => true).first
          if conflicting_user and conflicting_user != record
            record.errors.add(attr, 'mobile_number_in_use')
          end
        end
      else
        record.errors.add(attr, 'mobile_number_required') if record.mobile_required
      end
    end

    # Virtual attribute that controls validation
    attr_accessor :mobile_required
    attr_accessor :email_required

    # Virtual attribute that updates the encrypted password.
    attr_reader :password
    attr_reader :password_confirmation

    # Virtual atribute used for validation.
    attr_accessor :current_password

    scope :active, where(:deleted => false, :activated => true)
    scope :alive, where(:deleted => false)
    scope :in_store, lambda { |store|
      where(:store_id => store.id)
    }
    scope :having_email, lambda { |email_address|
      where(:email_address => normalize_email(email_address || ''))
    }
    scope :having_mobile, lambda { |mobile_number|
      where(:mobile_number => normalize_mobile(mobile_number || ''))
    }
    scope :having_name, lambda { |name|
      name = User.normalize_name(name)
      if name
        where("lower(name) = ?", name.downcase)
      else
        where('false')
      end
    }

    class << self
      def normalize_password(p)
        p.try(:strip)
      end

      def name_match?(a, b)
        a, b = normalize_name(a), normalize_name(b)
        a.downcase!
        b.downcase!
        a == b
      end

      def normalize_name(name)
        if name.present?
          name = name.dup
          name.strip!
          name.gsub!(/\s+/, ' ')
          name
        end
      end

      def normalize_mobile(number)
        if number
          number = NorwegianPhone.normalize(number)
          number = nil if number.length == 0
          number
        end
      end

      def mobile_valid?(number)
        NorwegianPhone.number_valid?(normalize_mobile(number))
      end

      def normalize_email(email)
        if email
          email = email.dup
          email.strip!
          email.downcase!
          email = nil if email.length == 0
          email
        end
      end

      def email_valid?(email)
        normalize_email(email) =~ EMAIL_FORMAT
      end
    end

    def name=(value)
      write_attribute(:name, User.normalize_name(value))
    end

    def email_address=(value)
      normalized = User.normalize_email(value)
      if self.email_address.blank? or normalized != self.email_address
        write_attribute(:email_address, normalized)
        self.email_verified = false
      end
    end

    def mobile_number=(value)
      normalized = User.normalize_mobile(value)
      if self.mobile_number.blank? or normalized != self.mobile_number
        write_attribute(:mobile_number, normalized)
        self.mobile_verified = false
      end
    end

    def password_match?(check_password)
      check_password = User.normalize_password(check_password)
      if self.password_hash =~ /^legacy:(.+)/
        # Legacy password support for historical reasons
        return $1 == legacy_hash(legacy_hash('(H3aP') + check_password)
      else
        return self.password_hash.present? &&
          BCrypt::Password.new(self.password_hash).is_password?(check_password)
      end
    end

    def password=(value)
      @password = value
      password_hash_will_change!
    end

    def password_confirmation=(value)
      @password_confirmation = value
      password_hash_will_change!
    end

    def active?
      !deleted?
    end

    def activated?
      super && active?
    end

    def activate!
      unless activated?
        self.activated = true
        self.activated_at = Time.now
        save(:validate => false)
      end
    end

    def delete!
      unless deleted?
        self.deleted = true
        self.deleted_at = Time.now
        self.mobile_number = nil
        self.mobile_verified = false
        self.email_address = nil
        self.email_verified = false
        save(:validate => false)
      end
    end

    private

      EMAIL_FORMAT = /\A\s*([^\s]+@[^\s]+)\s*\z/m.freeze
      MOBILE_FORMAT = /\A\s*(\+?[0-9\s-]+)\s*\z/m.freeze

      def legacy_hash(s)
        return Digest::SHA1.hexdigest("Do androids dream of #{s}?")[0..39]
      end

      def encrypt_password
        if @password
          if @password.blank?
            self.password_hash = nil
          else
            self.password_hash = BCrypt::Password.create(User.normalize_password(@password))
          end
        end
        true
      end

      def reset_password_attribute
        @password = nil
      end

      def validate_password?
        !!@password
      end

      def validate_password_confirmation?
        !!@password && !!@password_confirmation
      end

  end
end