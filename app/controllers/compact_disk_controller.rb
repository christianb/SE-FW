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
      @cds = CompactDisk.where('user_id != ?', current_user.id).paginate(:page => params[:page], :per_page => 10)
      #CompactDisk.where('user_id != ? AND in_transaction == ? AND visible == ?', current_user.id, false, true).order("id DESC").limit(10)
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
    
    if current_user.last_like == nil
      current_user.update_attribute(:last_like, Time.now-60*60)
    end
    
  end
  
  def destroy
    @cd = CompactDisk.find(params[:id])
    disk_user = User.find(@cd.user_id)
    
    # path to songs
    path = @cd.audio.path
    if !@cd.audio_file_name.nil?
      filename_with_ext = @cd.audio_file_name.gsub( /[^a-zA-Z0-9_\.]/, '_')
      path = path.chomp(filename_with_ext)
    end
    
    if (@cd.user_id == current_user.id)
      redirect_to myCDs_path
    else
      user = User.find(@cd.user_id)
      if (user.email_notification)
        
        params = {
          'method' => 'deletion_confirmation_compact_disk',
          'email' => user.email,
          'title' => @cd.title,
          'artist' => @cd.artist
        }
        
        Resque.enqueue(Email, params)
        #Notifier.deletion_confirmation_compact_disk(user.email, @cd.title, @cd.artist).deliver
      end
      redirect_to adminAllCDs_path
    end
    
    # Löschen aller Nachrichten zu der CD
    sent = disk_user.sent_messages.find(:all, :conditions => ["subject LIKE '%?%'", @cd.id])
    received = disk_user.received_messages.find(:all, :conditions => ["subject LIKE '%?%'", @cd.id])
    @sended = false
    @rvd = false
    
    sent.each do |s|
      cd_array = s.subject.split(';')
      split_array = cd_array[0].split(',')
      if (cd_array.include?(@cd.id.to_s))
        s.destroy
      end
    end
    
    received.each do |s|
      cd_array = s.subject.split(';')
      split_array = cd_array[0].split(',')
      if(cd_array.include?(@cd.id.to_s))
        s.destroy
      end
    end
    
    system("rm -rf #{path}")
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
    map = searchMBrainz(params[:artist], params[:title])
    @tracks = map[:tracks]
    logger.debug "cover url: "+map[:cover_url]
    @tr = @tracks.to_a.map! {|t| Hash[value: t]}
    #respond_to do |format|
     # format.html
      #format.js
    #end
    render xml: map
    
  end
  
  def create
    @cd = CompactDisk.new(params[:compact_disk])
    
    # lade Tracks von MusicBrainz
    #tracks = searchTracks(@cd.artist, @cd.title)
    #logger.debug 'tracks' +tracks.to_s
    
    #@songs = (params[:song])  
    respond_to do |format|
        if @cd.save
          # save songs from musicBrianz
          #if !tracks.nil?
          #  tracks.each { |t| 
          #    logger.debug "erstelle Song: "+t.to_s
          #    song = Song.new(:title => t.to_s, :compact_disk_id => @cd.id)
          #    song.save
          #  }
          #end
          
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
        flash[:notice] = "CD erfolgreich geaendert."
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
      
      # get all cds those are not mine and those are not in an transaktion
      @cds = CompactDisk.where('user_id != ?', current_user.id).order("created_at DESC").limit(10)#.paginate(:page => params[:page], :per_page => 9)
      #logger.debug "current_user.id = "+current_user.id.to_s
      #while @cds.size > 10 do
      #  @cds.pop
      #end
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
=begin
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
=end    
    if !@cd.in_transaction
      @cd.visible = true
      @cd.save
      redirect_to myCDs_path
    else
      flash[:error] = "CD befindet sich in einer Transaktion und kann nicht Freigegeben werden"
      redirect_to myCDs_path
    end
  end
  
  def like
    cd = CompactDisk.find(params[:id])
    
    user = User.find(current_user.id)
      if user.last_like < (Time.now-60*60)
        # es ist mehr als 1 Stunde seit dem letzten like vergangen
        user.update_attribute(:last_like, Time.now+60*60)
        cd.update_attribute(:rank,(cd.rank+1))
      end
    redirect_to :back
  end
  
  def best
    @best = CompactDisk.order("rank DESC").limit(10)
  end
  
  # Songs eines Albums
  def searchMBrainz(art, alb)
    query = Webservice::Query.new
    filter = Webservice::ReleaseFilter.new(:title => alb, :artist => art)
    release = query.get_releases(filter)
    if (!release.empty?)
      # get mbid of first
      mbid = release.entities[0].id.to_s;
      
      logger.debug "size of entities: "+release.entities.length.to_s
      #if release.entities[1] != nil
      #  mbid = release.entities[1].id.to_s;
      #end
    
      entities = release.entities
      asin = ""
      year = nil
      tracks = nil
      
      entities.each { |e|
        logger.debug "next entity"
        mbid = e.id.to_s
        r = query.get_release_by_id(mbid, :artist=>true, :tracks=>true, :release_events => true)
        if (!r.asin.nil?)
          asin = r.asin.to_s
          if year.nil?
            year = r.release_events[0].date.year
          end
          if tracks.nil?
            tracks = r.tracks
          end
          break
        end
      }
      
      
      logger.debug 'url_rels: '+release.to_s
      logger.debug "asin: "+asin
      
      #releations = release.get_relations( :relation_type => MusicBrainz::Model::NS_REL_1 + 'AmazonAsin' )
      #id = nil
      #p releations.map {|r| logger.debug "targeT: " +r.target}
      
      #logger.debug "id: "+id
      cover_url = nil
      unless asin.nil?
        cover_url = generate_cover_url(asin)
      else
        cover_url = ""
      end
      
      logger.debug "cover url: "+cover_url
      
      #logger.debug "r.target"+releations.artist
      #logger.debug "title: "+ release.title
      #logger.debug "artist: "+release.artist.name
      
      # alle daten in einer map zurückgeben
      # keys :tracks, :cover_url, :genre, :release_date
      
      results_from_rbrainz = {
          :tracks => tracks.to_a,
          :cover_url => cover_url,
          :year => year
      }
      
      #logger.debug "show cover from map: "+amap[:cover_url]
      #logger.debug "show tracks from map: "+amap[:tracks].inspect
      
      return results_from_rbrainz
    end
      return nil
  end
  
  def generate_cover_url (id)
    return ("http://images.amazon.com/images/P/"+id+".jpg")
  end
  
  def delete_demo_songs
    @cd = CompactDisk.find(params[:id])
    path = @cd.audio.path
    filename_with_ext = @cd.audio_file_name.gsub( /[^a-zA-Z0-9_\.]/, '_')
    path = path.chomp(filename_with_ext)
    @cd.update_attribute(:audio_file_name, nil)
    @cd.update_attribute(:last_audio_file_name, nil)
    
    system("rm -rf #{path}")
    
    redirect_to :back
  end
end
