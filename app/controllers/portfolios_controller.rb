class PortfoliosController < ApplicationController
  before_action :authenticate_user!
  before_action :set_portfolio, only: [:show, :performance, :edit, :update, :destroy]

  # GET /portfolios
  # GET /portfolios.json
  def index
    @portfolios = Portfolio.where(:user => current_user)
  end

  # GET /portfolios/1
  # GET /portfolios/1.json
  def show
    @watched_positions = @portfolio.watched_positions
  end

  # GET /portfolios/1
  # GET /portfolios/1.json
  def performance

    d1 = Date.new(2017,1,1)
    d2 = Date.new(2018,2,20)

    @performance = Performance.new(@portfolio,d1,d2)

    @p = @performance
    @relative_positions_start = @p.relative_positions(@p.start_date)
    @relative_positions_end = @p.relative_positions(@p.end_date)

    # Render performance view

  end

  # GET /portfolios/new
  def new
    @portfolio = Portfolio.new
  end

  # GET /portfolios/1/edit
  def edit
  end

  # POST /portfolios
  # POST /portfolios.json
  def create

    file = portfolio_params["positions"]
    txfile = portfolio_params["transactions"]

    label = portfolio_params["label"]

    User.current = current_user
    @portfolio = Position.import_csv(file.path)

    @portfolio = Transaction.import_csv(txfile.path)

    #@portfolio = Portfolio.new(portfolio_params)
    #@portfolio.user = current_user
    @portfolio.label = label

    respond_to do |format|
      if @portfolio.save
        format.html { redirect_to @portfolio, notice: 'Portfolio was successfully created.' }
        format.json { render :show, status: :created, location: @portfolio }
      else
        format.html { render :new }
        format.json { render json: @portfolio.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /portfolios/1
  # PATCH/PUT /portfolios/1.json
  def update
    respond_to do |format|
      if @portfolio.update(portfolio_params)
        format.html { redirect_to @portfolio, notice: 'Portfolio was successfully updated.' }
        format.json { render :show, status: :ok, location: @portfolio }
      else
        format.html { render :edit }
        format.json { render json: @portfolio.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /portfolios/1
  # DELETE /portfolios/1.json
  def destroy
    @portfolio.destroy
    respond_to do |format|
      format.html { redirect_to portfolios_url, notice: 'Portfolio was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_portfolio
      @portfolio = Portfolio.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def portfolio_params
      params.require(:portfolio).permit(:label, :positions, :transactions)
    end
end
