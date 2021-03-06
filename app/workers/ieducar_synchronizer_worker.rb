class IeducarSynchronizerWorker
  include Sidekiq::Worker
  include Sidekiq::Status::Worker

  sidekiq_options unique: :until_and_while_executing, retry: false, dead: false

  # Sidekiq-status expiration
  def expiration
    @expiration ||= 60 * 60 * 24 * 2 # 2 days
  end

  def perform(entity_id = nil, synchronization_id = nil)
    if entity_id && synchronization_id
      perform_for_entity(
        Entity.find(entity_id),
        synchronization_id
      )
    else
      all_entities.each do |entity|
        entity.using_connection do
          configuration = IeducarApiConfiguration.current
          next unless configuration.persisted?

          configuration.start_synchronization(User.first, entity.id)
        end
      end
    end
  end

  private

  BASIC_SYNCHRONIZERS = [
    KnowledgeAreasSynchronizer.to_s,
    DisciplinesSynchronizer.to_s,
    StudentsSynchronizer.to_s,
    DeficienciesSynchronizer.to_s,
    RoundingTablesSynchronizer.to_s,
    RecoveryExamRulesSynchronizer.to_s,
    CoursesGradesClassroomsSynchronizer.to_s,
    TeachersSynchronizer.to_s,
    StudentEnrollmentDependenceSynchronizer.to_s,
    ExamRulesSynchronizer.to_s,
    StudentEnrollmentSynchronizer.to_s,
    SpecificStepClassroomsSynchronizer.to_s,
    StudentEnrollmentExemptedDisciplinesSynchronizer.to_s
  ].freeze

  def perform_for_entity(entity, synchronization_id)
    entity.using_connection do
      begin
        synchronization = IeducarApiSynchronization.started.find(synchronization_id)
        worker_batch = synchronization.worker_batch

        break unless synchronization.started?

        total_in_batch = []

        total BASIC_SYNCHRONIZERS.size

        BASIC_SYNCHRONIZERS.each_with_index do |klass, index|
          at(index, "#{entity.name} - #{klass} (#{index}/#{BASIC_SYNCHRONIZERS.size})")

          increment_total(total_in_batch) do
            klass.constantize.synchronize_in_batch!(
              synchronization,
              worker_batch,
              years_to_synchronize,
              nil,
              entity.id
            )
          end
        end

        worker_batch.with_lock do
          worker_batch.update(total_workers: total_in_batch.sum)
          synchronization.mark_as_completed!
        end

        at(BASIC_SYNCHRONIZERS.size, "#{entity.name} - Finalizado!")
      rescue StandardError => error
        synchronization.mark_as_error!('Erro desconhecido.', error.message) if error.class != Sidekiq::Shutdown

        Honeybadger.notify(error)

        raise error
      end
    end
  end

  def years_to_synchronize
    # TODO voltar a sincronizar todos os anos uma vez por semana (Sábado)
    @years ||= Unity.with_api_code
                    .joins(:school_calendars)
                    .pluck('school_calendars.year')
                    .uniq
                    .sort
                    .compact
                    .last(2)
  end

  def all_entities
    Entity.active
  end

  def increment_total(total_in_batch, &block)
    total_in_batch << 1

    block.yield
  end
end
