class SchoolCalendarsController < ApplicationController
  has_scope :page, default: 1
  has_scope :per, default: 10

  def index
    @school_calendars = apply_scopes(SchoolCalendar).includes(:unity)
                                                    .filter(filtering_params(params[:search]))
                                                    .ordered

    authorize @school_calendars

    @unities = Unity.ordered
  end

  def edit
    @school_calendar = resource

    authorize resource
  end

  def update
    resource.assign_attributes resource_params

    authorize resource

    if resource.save
      respond_with resource, location: school_calendars_path
    else
      render :edit
    end
  end

  def destroy
    authorize resource

    resource_destroyer = ResourceDestroyer.new.destroy(resource)

    if resource_destroyer.has_error?
      flash[:error] = resource_destroyer.error_message
      flash[:notice] = ""
    end

    respond_with resource, location: school_calendars_path
  end

  def history
    @school_calendar = SchoolCalendar.find(params[:id])

    authorize @school_calendar

    respond_with @school_calendar
  end

  def synchronize
    @school_calendars = SchoolCalendarsParser.parse!(IeducarApiConfiguration.current)

    authorize(SchoolCalendar, :create?)
    authorize(SchoolCalendar, :update?)
  end

  def create_and_update_batch
    begin
      if SchoolCalendarsCreator.create!(params[:synchronize]) && SchoolCalendarsUpdater.update!(params[:synchronize])
        redirect_to school_calendars_path, notice: t('.notice')
      else
        redirect_to synchronize_school_calendars_path, alert: t('.alert')
      end
    rescue SchoolCalendarsCreator::InvalidSchoolCalendarError => error
      redirect_to synchronize_school_calendars_path, alert: error.to_s
    rescue SchoolCalendarsCreator::InvalidClassroomCalendarError => error
      redirect_to synchronize_school_calendars_path, alert: error.to_s
    rescue SchoolCalendarsUpdater::InvalidSchoolCalendarError => error
      redirect_to synchronize_school_calendars_path, alert: error.to_s
    rescue SchoolCalendarsUpdater::InvalidClassroomCalendarError => error
      redirect_to synchronize_school_calendars_path, alert: error.to_s
    rescue
      redirect_to synchronize_school_calendars_path, alert: t('.alert')
    end
  end

  private

  def filtering_params(params)
    params = {} unless params
    params.slice(:by_year,
                 :by_unity_id)
  end

  def resource
    @school_calendar ||= case params[:action]
    when 'new', 'create'
      SchoolCalendar.new
    when 'edit', 'update', 'destroy'
      SchoolCalendar.find(params[:id])
    end.localized
  end

  def resource_params
    params.require(:school_calendar).permit(:year,
                                            :number_of_classes,
                                            steps_attributes: [:id,
                                                               :start_at,
                                                               :end_at,
                                                               :start_date_for_posting,
                                                               :end_date_for_posting,
                                                               :_destroy],
                                            classrooms_attributes: [:id,
                                                                    :classroom,
                                                                    :_destroy,
                                            classroom_steps_attributes: [:id,
                                                               :start_at,
                                                               :end_at,
                                                               :start_date_for_posting,
                                                               :end_date_for_posting]])
  end
end
