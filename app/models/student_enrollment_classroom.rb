class StudentEnrollmentClassroom < ActiveRecord::Base
  include Audit
  audited
  has_associated_audits

  belongs_to :classroom
  belongs_to :student_enrollment

  has_enumeration_for :period, with: Periods, skip_validation: true

  scope :by_classroom, ->(classroom_id) { where(classroom_id: classroom_id) }
  scope :by_date, lambda { |date|
    where("? >= joined_at AND (? < left_at OR coalesce(left_at, '') = '')", date.to_date, date.to_date)
  }
  scope :by_date_not_before, ->(date) { where.not('joined_at < ?', date) }
  scope :show_as_inactive, -> { where(show_as_inactive_when_not_in_date: 't') }
  scope :by_grade, ->(grade_id) { joins(:classroom).where(classrooms: { grade_id: grade_id }) }
  scope :by_student, ->(student_id) { joins(student_enrollment: :student).where(students: { id: student_id }) }
  scope :by_student_enrollment, ->(student_enrollment_id) { where(student_enrollment_id: student_enrollment_id) }
  scope :active, lambda {
    joins(:student_enrollment).where(student_enrollments: { active: IeducarBooleanState::ACTIVE })
  }
  scope :ordered, -> { order(:api_code) }

  def self.by_date_range(start_at, end_at)
    where("(CASE
              WHEN COALESCE(student_enrollment_classrooms.left_at) = '' THEN
                student_enrollment_classrooms.joined_at <= :end_at
              ELSE
                student_enrollment_classrooms.joined_at <= :end_at AND
                student_enrollment_classrooms.left_at >= :start_at AND
                student_enrollment_classrooms.joined_at <> student_enrollment_classrooms.left_at
            END)", end_at: end_at.to_date, start_at: start_at.to_date)
  end
end
