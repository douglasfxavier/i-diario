class CreateCourses < ActiveRecord::Migration
  def change
    create_table :courses do |t|
      t.string :description
      t.string :api_code


      t.timestamps
    end
  end
end
