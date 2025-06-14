class DashboardsController < ApplicationController
  before_action :authenticate_user!

  def index
    @upcoming_notes = Note.where(user: current_user)
                              .where("due_date IS NOT NULL AND due_date > ?", Time.current)
                              .where.not(status: :completed)
                              .limit(5)

    @missed_notes = Note.where(user: current_user)
                            .where("due_date IS NOT NULL AND due_date <= ?", Time.current)
                            .where.not(status: :completed)


    @missed_notes_count = @missed_notes.count

    users_steps =   @steps = Step.joins(:note).where(notes: { user: current_user })


    @completed_steps = users_steps.where(status: :completed).count
    @pending_steps = users_steps.where.not(status: :completed).count
    @total_notes = Note.where(user: current_user).count
  end
end
