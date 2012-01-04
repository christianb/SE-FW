require 'rbrainz'
include MusicBrainz

class CompactDiskController < ApplicationController
  before_filter :set_locale
  before_filter :checkUser, :only =>[:destroy, :update]
  before_filter :signed_in?, :only => [:show]
  #load_and_authorize_resource :only => [:show, :destroy]
  
  def signed_in?
    unless user_signed_in?
      flash[:alert] = "Als Gast koennen sie sich die CD nicht ansehen!"
      redirect_to :back
    end
  end
  
  # Eigentümer des CD Prüfen
  def checkUser
     @cd = CompactDisk.find(params[:id])
     unless (@cd.user_id == current_user.id || AdminController.isAdmin(current_user))
       flash[:error] = "Dies ist nicht Ihre CD"
       redirect_to welcome_path
     end
  end
  
  def index
    #@cds = CompactDisk.where(:user_id => current_user.id)
    #@cds = CompactDisk.all
    if user_signed_in?
      @cds = CompactDisk.where(CompactDisk.arel_table[:user_id].not_eq(current_user.id)).paginate(:page => params[:page], :per_page => 10)
    else
      @cds = CompactDisk.paginate(:page => params[:page], :per_page => 10)
    end
  end
  
  def myCDs
    #@allCDs = CompactDisk.all
   # @myCDs = CompactDisk.where(:user_id => current_user.id)
    @myCDs = CompactDisk.where(:user_id => current_user.id).order("updated_at DESC").paginate(:page => params[:page], :per_page => 25)

  end
  
  def show
    @cd = CompactDisk.find(params[:id])
    #@songs = Song.where(:compact_disk_id => @cd.id)
    @songs = @cd.songs
    @user = User.find(@cd.user_id)
  end
  
  def destroy
    @cd = CompactDisk.find(params[:id])
    
    if (@cd.user_id == current_user.id)
      redirect_to myCDs_path
    else
      user = User.find(@cd.user_id)
      if (user.email_notification)
        Notifier.deletion_confirmation_compact_disk(user.email, @cd.title, @cd.artist).deliver
      end
      redirect_to adminAllCDs_path
    end
    
    title = @cd.title
    @cd.destroy  
    flash[:notice] = "CD: "+title+" erfolgreich geloescht."
  end
  
  def new
    logger.debug 'call new'
    @cd = CompactDisk.new
    logger.debug 'new CD'
    @cd.songs.build
    #1.times { @cd.songs.build }
  end
  
  def mbrainz
    #logger.debug 'call mbrainz'
    @tracks = searchTracks(params[:artist], params[:title])
    @tr = @tracks.to_a.map! {|t| Hash[value: t]}
    #respond_to do |format|
     # format.html
      #format.js
    #end
    render xml: @tr
    
  end
  
  def create
    @cd = CompactDisk.new(params[:compact_disk])
    
    # lade Tracks von MusicBrainz
    tracks = searchTracks(@cd.artist, @cd.title)
    #logger.debug 'tracks' +tracks.to_s
    
    #@songs = (params[:song])  
    respond_to do |format|
        if @cd.save
          # save songs from musicBrianz
          if !tracks.nil?
            tracks.each { |t| 
              logger.debug "erstelle Song: "+t.to_s
              song = Song.new(:title => t.to_s, :compact_disk_id => @cd.id)
              song.save
            }
          end
          
          # try to convert to ogg if needed
          @cd.convert_to_ogg
          #@cd.update_attribute(:audio_file_name, @cd.audio_file_name+".ogg")
          #@cd.update_attribute(:audio_content_type, "audio/ogg")
          #logger.debug "new audio path"+@cd.audio.path
          
          format.html  { redirect_to(myCDs_path(current_user.id),
                        :notice => 'CD erfolgreich angelegt.') }
          format.json  { render :json => @cd,
                        :status => :created, :location => @cd }
          
        #  @songs.each do |s|
         #     @song  = Song.new(:compact_disk_id => @cd.id, :title => s[1])
          #    @song.save
          #end
        else
          format.html  { render :action => "new" }
          format.json  { render :json => @cd.errors,
                        :status => :unprocessable_entity }
        end
      end
  end
  
  def edit
    @cd = CompactDisk.find(params[:id])
    #@songs = Song.where(:compact_disk_id => @cd.id)
    #@cd.songs.build
    
  end
  
  def update
    @cd = CompactDisk.find(params[:id])
#    @songs = params[:song]
#    .except(:song)
    respond_to do |format|
      if @cd.update_attributes(params[:compact_disk])
        @cd.convert_to_ogg
        #allsongs = Song.where(:all, :compact_disk_id => @cd.id)
        #allsongs.each do |as|
        #  if as.id == params[:song][:index]
        #    as.title = params[:song]['1'][:title]
        #    as.save
        #  end
        #end
        format.html { redirect_to action: "show" }
      else
        format.html { render action: "edit" }
      end
    end
  end
  
  #def find_by_artist
  #  @cd = CompactDisk.where
  #end
  
  def swap
    if (!user_signed_in?)
      redirect_to welcome_path
    else
      @cd = CompactDisk.find(params[:id])
      @user = User.find(@cd.user_id)
      @userCDs = CompactDisk.where(:user_id => @cd.user_id)
      @myCDs = CompactDisk.where(:user_id => current_user.id)
    end
  end
  
  
  
  # get the last 10 Disks
  def latest
    if (user_signed_in?)
      @cds = CompactDisk.where(CompactDisk.arel_table[:user_id].not_eq(current_user.id)).order("id DESC").limit(10)#.paginate(:page => params[:page], :per_page => 9)
    else
      @cds = CompactDisk.order("id DESC").limit(10)#.paginate(:page => params[:page], :per_page => 9)
    end
  end
  
  # Anzeigen aller CDs einez Nutzers + Nutzerinformationen
  def all_user_cds
    @cds = CompactDisk.where(:user_id => params[:id]).paginate(:page => params[:page], :per_page => 10)
    @user = User.find(params[:id])
  end
  
  # Sichtbarkeit einer CD ändern
  def makeVisible
    @cd = CompactDisk.find(params[:id])
    @user = User.find(@cd.user_id)

    @sent_msg = @user.sent_messages(:all)
    @received_msg = @user.received_messages(:all)

    @in_transaction = false
        
    @sent_msg.each do |sm|
      if sm.subject.include?(@cd.id.to_s)
        @in_transaction = true
        break
      end
    end
    
    @received_msg.each do |rm|
      if rm.subject.include?(@cd.id.to_s)
        @in_transaction = true
        break
      end
    end
    
    if !@in_transaction
      @cd.visible = true
      @cd.save
      redirect_to myCDs_path
    else
      flash[:error] = "CD befindet sich in einer Transaktion"
      redirect_to myCDs_path
    end
  end
  
  def like
    cd = CompactDisk.find(params[:id])
    cd.update_attribute(:rank,(cd.rank+1))
    redirect_to :back
  end
  
  def best
    @best = CompactDisk.order("rank DESC").limit(10)
  end
  
  # Songs eines Albums
  def searchTracks(art, alb)
    query = Webservice::Query.new
    filter = Webservice::ReleaseFilter.new(:title => alb, :artist => art)
    release = query.get_releases(filter)
    if (!release.empty?)
      # get mbid of first
      mbid = release.entities[0].id.to_s;
    
      release = query.get_release_by_id(mbid, :artist=>true, :tracks=>true)
      #logger.debug "title: "+ release.title
      #logger.debug "artist: "+release.artist.name
      
      return release.tracks
    end
      return nil
  end
end
