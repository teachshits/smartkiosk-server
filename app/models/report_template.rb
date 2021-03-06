class ReportTemplate < ActiveRecord::Base

  attr_accessor :report_builder_instance

  has_paper_trail

  #
  # RELATIONS
  #
  belongs_to :user
  has_many :reports, :dependent => :destroy

  #
  # VALIDATIONS
  #
  validates :title, :presence => true

  #
  # MODIFCIATIONS
  #
  serialize :groupping
  serialize :fields
  serialize :calculations
  serialize :conditions

  #
  # METHODS
  #
  def report_builder(report=nil)
    return report_builder_instance unless report_builder_instance.nil?

    report_builder_instance = ReportBuilder.constantize(kind)
    report_builder_instance = report_builder_instance.new(report) if report_builder_instance

    return report_builder_instance
  end

  def respond_to?(key, include_private=false)
    return true if key.to_s.starts_with?('condition_')
    super(key, include_private)
  end

  def method_missing(name, *args, &block)
    return super unless name.to_s.starts_with?('condition_')

    self.conditions ||= {}
    name = name.to_s.gsub('condition_', '')

    if name[-1] == '='
      name = name[0, name.length-1]
      self.conditions[name] = (args[0].is_a?(Array) ? args[0].select{|x| !x.blank?} : args[0])
    else
      self.conditions[name]
    end
  end
end
