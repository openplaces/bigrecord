class Employee < BigRecord::Base

  column 'attribute:first_name',      :string
  column 'attribute:middle_name',     :string
  column 'attribute:last_name',       :string
  column 'attribute:email',           :string
  column 'attribute:title',           :string
  column 'attribute:company_id',      :string
  column 'attribute:password',        :string
  column 'attribute:gender',          :string   # it's not discrimination
  column 'attribute:age',             :integer

  validates_presence_of   :first_name, :last_name
  validates_length_of     :first_name, :last_name, :within => 2..50
  validates_length_of     :middle_name, :within => 1..50, :allow_nil => true
  validates_format_of     :first_name, :last_name, :with => /^[\w-]/
  validates_format_of     :middle_name, :with => /^[\w-]/, :allow_nil => true
  #validates_uniqueness_of :name
  validates_exclusion_of  :first_name, :last_name, :in => %w( admin superuser )
  validates_exclusion_of  :middle_name, :in => %w( admin superuser ), :allow_nil => true

  validates_presence_of   :email

  validates_inclusion_of :gender, :in => %w( m f )

  validates_confirmation_of :password

  validates_acceptance_of :contract


  belongs_to :company

end
