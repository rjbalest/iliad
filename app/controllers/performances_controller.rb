class PerformancesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_portfolio, only: [:index]
  before_action :set_performance, only: [:index, :show, :edit, :update, :destroy]

  # GET /performances
  # GET /performances.json
  def index
    #@performances = Performance.all
    @performances = []
    @p = @performance
    @relative_positions_start = @p.relative_positions(@p.start_date)
    @relative_positions_end = @p.relative_positions(@p.end_date)
  end

  # GET /performances/1
  # GET /performances/1.json
  def show
  end

  # GET /performances/new
  def new
    @performance = Performance.new
  end

  # GET /performances/1/edit
  def edit
  end

  # POST /performances
  # POST /performances.json
  def create
    @performance = Performance.new(performance_params)

    respond_to do |format|
      if @performance.save
        format.html { redirect_to @performance, notice: 'Performance was successfully created.' }
        format.json { render :show, status: :created, location: @performance }
      else
        format.html { render :new }
        format.json { render json: @performance.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /performances/1
  # PATCH/PUT /performances/1.json
  def update
    respond_to do |format|
      if @performance.update(performance_params)
        format.html { redirect_to @performance, notice: 'Performance was successfully updated.' }
        format.json { render :show, status: :ok, location: @performance }
      else
        format.html { render :edit }
        format.json { render json: @performance.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /performances/1
  # DELETE /performances/1.json
  def destroy
    @performance.destroy
    respond_to do |format|
      format.html { redirect_to performances_url, notice: 'Performance was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_performance

      # Default to year to date
      d2 = Date.today
      d1 = Date.new(d2.year,1,1)

      unless params[:start_date].blank?
        d1 = Date.parse(params[:start_date])
      end
      unless params[:end_date].blank?
        d2 = Date.parse(params[:end_date])
      end

      @performance = Performance.new(@portfolio,d1,d2)
    end

  def set_portfolio
    @portfolio = Portfolio.find(params[:portfolio_id])
  end

    # Never trust parameters from the scary internet, only allow the white list through.
    def performance_params
      params.fetch(:performance, {})
    end
end
