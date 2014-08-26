# encoding: utf-8
# Pseudo-Model zur Speicherung der Anmeldeinformation

class Database < Hash
  include ApplicationHelper # Erweiterung der Controller um Helper-Methoden des GUI's

#  attr_accessor :id, :user, :password, :privilege, :host, :port, :sid, :sid_usage, :dbid, :authorization, :locale,
#                :db_block_size, :version, :wordsize

  def initialize( params = {} )
    self[:tns]      = params[:tns]
    self[:user]     = params[:user]
    self[:password] = params[:password]
    self[:privilege]= params[:privilege]
    self[:host]     = params[:host]
    self[:port]     = params[:port]
    self[:sid]      = params[:sid]
    self[:sid_usage]= :SID
    self[:dbid]     = params[:dbid]         # Database ID aus V$Database
    self[:authorization] = params[:authorization]  # Autorisierung für spezielle DB's
    self[:locale]   = params[:locale]
    self[:version]  = params[:version]         # DB-Version Oracle
    self[:wordsize] = params[:wordsize]         # Wortbreite in Byte (4/8 für 32/64 bit)
  end

  def tns=(param)
    @tns = param
  end
  
  # Rueck-Konvertierung in params-Hash
  def to_params
    {
      :id       => self[:id],
      :user     => self[:user],
      :password => self[:password],
      :privilege=> self[:privilege],
      :host     => self[:host],
      :port     => self[:port],
      :sid      => self[:sid],
      :authorization => self[:authorization],
      :locale   => self[:locale],
      :version  => self[:version],
      :wordsize => self[:wordsize],
    }
  end






end
