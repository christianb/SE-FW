class ApplicationController < ActionController::Base
  protect_from_forgery
  #before_filter :set_i18n_locale_from_params
  before_filter :set_locale
  
  def after_sign_in_path_for(resource)
      flash.now[:notice] = nil
      myCDs_path(current_user)
  end
  
  def after_update_path_for(resource)
    user_path(current_user)
  end
  
  def after_sign_out_path_for(resource_or_scope)
    welcome_path
  end
  
  def set_locale
    I18n.locale = params[:locale] || I18n.default_locale
  end
  
    def set_i18n_locale_from_params
      if params[:lcoale]
        if I18n.available_locales.include?(params[:locale].to_sym)
          I18n.locale = params[:locale]
        else
          flash.now[:notice] = "#{params[:locale]} translation not available"
          logger.error flash.now[:notice]
        end
      end
    end
    
    def default_url_options
      { :locale => I18n.locale }
    end
    
    # search for a user with a given name
    def search
      name = params[:querry].downcase
      
      if (!name.empty?)
        #if !name.empty?
      
        # if param is number
        
        #if (num != 0)
        #  logger.debug "search num: "+num.to_s
        #  @cds = CompactDisk.where("cast(year as text) LIKE ?","%#{num}%")
        #else
          @songs = Song.where("lower(title) like ?","%#{name}%")
          #logger.debug 'songs size = '+@songs.size.to_s
          @cds = CompactDisk.where("lower(artist) LIKE ? OR lower(title) LIKE ? OR lower(genre) LIKE ?", "%#{name}%","%#{name}%","%#{name}%")
        #end
        @users = User.where("lower(firstname) LIKE ? OR lower(lastname) LIKE ? OR lower(email) LIKE ? OR lower(alias) LIKE ?","%#{name}%","%#{name}%","%#{name}%","%#{name}%")
        
        num = name.to_i
        if (num > 0)
          cds_year = CompactDisk.where("cast(year as text) LIKE ?","%#{num}%")
        
          cds_year.each {|cd|
            if (!@cds.include?(cd))
              @cds = @cds.push(cd)
            end
          }
        end
        
        
        @songs.each { |s| 
          cd = CompactDisk.where(:id => s.compact_disk_id)
          if cd.length > 0
            #logger.debug 'size cds = '+@cds.length.to_s
            #logger.debug 'title = '+cd.first.title
            #cd.push(@cds)
            
            # if cd is not in array
            if (!@cds.include?(cd.first))
              @cds = @cds.push(cd.first)
            end
            #logger.debug 'size cds = '+@cds.length.to_s
          end
        }

        # delete own cd's
        if (user_signed_in? && !current_user.search_own_cds)
          @cds = @cds.delete_if {|c| c.user_id == current_user.id}
        end
      
        # delete own user
        if (user_signed_in?)
          @users = @users.delete_if {|u| u.id == current_user.id}
        end
      else
        # @Christian S.: Bitte zeigen eine Fehlermeldung an wenn Suchstring leer ist. Danke :)
        redirect_to :back
      end
    end
  
    def impressum
    end
    
    # Abfrage für Autocomplete beim Suchfeld
    def autoCompl
      if params[:term]
          like = "%".concat(params[:term].downcase.concat("%"))
          
          cds_artist = CompactDisk.where("lower(artist) like ?", like)
          cds_title = CompactDisk.where("lower(title) like ?", like)
          cds_genre = CompactDisk.where("lower(genre) like ?", like)
          songs = Song.where("lower(title) LIKE ?", like)
          
          user_first = User.where("lower(firstname) like ?", like)
          user_last = User.where("lower(lastname) like ?", like)
          user_alias = User.where("lower(alias) like ?", like)
          user_email = User.where("lower(email) like ?", like)
          
          # entferne eigene cds
          if (user_signed_in? && !current_user.search_own_cds)
             cds_artist = cds_artist.delete_if {|c| c.user_id == current_user.id}
             cds_title = cds_title.delete_if {|c| c.user_id == current_user.id}
             cds_genre = cds_genre.delete_if {|c| c.user_id == current_user.id}
             songs = songs.delete_if {|s| s.compact_disk.user_id == current_user.id}
          end
          
          # entferne eigenen user
          if (user_signed_in?)
            user_first = user_first.delete_if {|u| u.id == current_user.id}
            user_last = user_last.delete_if {|u| u.id == current_user.id}
            user_alias = user_alias.delete_if {|u| u.id == current_user.id}
            user_email = user_email.delete_if {|u| u.id == current_user.id}
          end
          
          cds_artist.each { |cd| cd[:artist].downcase! } # um doppelte einträge zu vermeiden, mache alles klein
          cds_artist.uniq! { |cd| cd[:artist] } # lösche doppelte einträge
          cds_title.each { |cd| cd[:title].downcase! } # um doppelte einträge zu vermeiden, mache alles klein
          cds_title.uniq! { |cd| cd[:title] } # lösche doppelte einträge
          cds_genre.each { |cd| cd[:genre].downcase! } # um doppelte einträge zu vermeiden, mache alles klein
          cds_genre.uniq! { |cd| cd[:genre] } # lösche doppelte einträge
          
          songs.each { |song| song[:title].downcase! } # um doppelte einträge zu vermeiden, mache alles klein
          songs.uniq! { |song| song[:title] } # lösche doppelte einträge
          
          user_first.each { |u| u[:firstname].downcase! } # um doppelte einträge zu vermeiden, mache alles klein
          user_first.uniq! { |u| u[:firstname] } # lösche doppelte einträge
          user_last.each { |u| u[:lastname].downcase! } # um doppelte einträge zu vermeiden, mache alles klein
          user_last.uniq! { |u| u[:lastname] } # lösche doppelte einträge
          user_alias.each { |u| u[:alias].downcase! } # um doppelte einträge zu vermeiden, mache alles klein
          user_alias.uniq! { |u| u[:alias] } # lösche doppelte einträge
          user_email.each { |u| u[:email].downcase! } # um doppelte einträge zu vermeiden, mache alles klein
          user_email.uniq! { |u| u[:email] } # lösche doppelte einträge
          
      else
          cds = CompactDisk.all
          users = User.all
      end
        list_artist = cds_artist.map {|u| Hash[ id: u.id, label: u.artist, name: u.artist]}
        list_title = cds_title.map {|u| Hash[ id: u.id, label: u.title, name: u.title]}
        list_genre = cds_genre.map {|u| Hash[ id: u.id, label: u.genre, name: u.genre]}
        list_songs = songs.map {|u| Hash[ id: u.id, label: u.title, name: u.title]}
        #list_genre = list_genre.uniq
        #logger.debug list_genre
        #logger.debug 'list_genre size = '+list_genre.size.to_s
        
        list_fistname = user_first.map {|u| Hash[ id: u.id, label: u.firstname, name: u.firstname]}
        list_lastname = user_last.map {|u| Hash[ id: u.id, label: u.lastname, name: u.lastname]}
        list_alias = user_alias.map {|u| Hash[ id: u.id, label: u.alias, name: u.alias]}
        list_email = user_email.map {|u| Hash[ id: u.id, label: u.email, name: u.email]}
        
        list = list_title + list_artist + list_genre + list_lastname + list_fistname + list_alias + list_email + list_songs
        list.uniq! {|l| l[:label]} # entferne doppelte einträge aus über alle kategorien
        render json: list
    end
end
