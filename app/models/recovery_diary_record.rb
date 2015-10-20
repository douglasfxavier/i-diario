class RecoveryDiaryRecord < ActiveRecord::Base
  include Audit

  acts_as_copy_target

  audited

  belongs_to :unity
  belongs_to :classroom
  belongs_to :discipline

  has_many :students, class_name: 'RecoveryDiaryRecordStudent', dependent: :destroy

  accepts_nested_attributes_for :students, allow_destroy: true

  has_one :school_term_recovery_diary_record
  has_one :final_recovery_diary_record

  validates :unity, presence: true
  validates :classroom, presence: true
  validates :discipline, presence: true
  validates :recorded_at, presence: true
end
