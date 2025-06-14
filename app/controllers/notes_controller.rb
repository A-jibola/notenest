class NotesController < ApplicationController
  before_action :authenticate_user!

  def index
    @notes = current_user.notes
  end

  def show
    @note = current_user.notes.find(params[:id])
  end

  def new
    @note = current_user.notes.new
  end

  def create
    @note = current_user.notes.new(note_params)

    if @note.save
      process_tags
      redirect_to note_path(@note), notice: "Note was successfully created"
    else
      render :new
    end
  end

  def edit
    @note = current_user.notes.find(params[:id])
  end

  def update
    @note = current_user.notes.find(params[:id])
    binding.break

    previous_incomplete_steps = @note.steps.where.not(status: "completed").pluck(:id)

    if @note.update(note_params)
      newly_completed_steps = @note.steps.where(id: previous_incomplete_steps, status: "completed")

      # foreach newly completed step, create a notification
      newly_completed_steps.each do |step|
        Notification.create!(
        user: @note.user, notifiable: step,
        title: "This step: #{step.name} has been completed",
        read: false, notification_type: "step", send_at: Time.current
      )
      end

      # if the note is completed, create a notification
      if @note.saved_change_to_attribute("status") && @note.completed?
        Notification.create!(
        user: @note.user, notifiable: @note,
        title: "This note: #{@note.title} has been completed",
        read: false, notification_type: "note", send_at: Time.current
      )
      end
      redirect_to @note, notice: "Note was successfully updated"
    else
      render :edit
    end
  end

  def destroy
    @note = current_user.notes.find(params[:id])
    @note.destroy
    redirect_to notes_path, notice: "Note was succesfully destroyed"
  end


  # private
  def note_params
    params.require(:note).permit(:title, :description, :due_date, :status, :tags_input, :reminder_time,
    steps_attributes: [ :id, :name, :summary, :details, :status, :due_date, :order, :reminder_at, :_destroy ])
  end

  def process_tags
    return if params[:note][:tags_input].blank?

    tag_names = params[:note][:tags_input].split(",").map(&:strip).uniq
    tags = tag_names.map { |name| current_user.tags.find_or_create_by(name: name) }
    @note.tags = tags
  end
end
