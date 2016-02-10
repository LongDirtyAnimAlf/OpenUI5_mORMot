unit dataserver;

{$I Synopse.inc}

interface

uses
  {$ifdef Darwin}
  Unix,
  {$endif}
  SysUtils, Classes,
  SynCommons, mORMot,
  mORMotSQLite3, SynSQLite3Static,
  ODataRestServer,
  SampleData;

type

  TmORMotODataServer = class(TSQLRestServerDB)
  private
    Model:TSQLModel;
  protected
    fRootFolder: TFileName;
    fDataFolder: TFileName;
    fAppFolder: TFileName;
  public
    Server: TODataHttpServer;
    constructor Create(const aRootFolder: TFileName=''; const aRootURI: RawUTF8='root'); reintroduce;
    destructor Destroy; override;
  end;

implementation

uses
  SynLog;


constructor TmORMotODataServer.Create(const aRootFolder: TFileName; const aRootURI: RawUTF8);
begin

  fRootFolder := EnsureDirectoryExists(ExpandFileName(aRootFolder),true);
  if fRootFolder=PathDelim then fRootFolder:='.'+fRootFolder;

  //fDataFolder := EnsureDirectoryExists(fRootFolder+'data'+PathDelim,true);
  //if fDataFolder=PathDelim then fDataFolder:='.'+fDataFolder;

  fAppFolder := EnsureDirectoryExists(ExpandFileName(''),true);
  if fAppFolder=PathDelim then fAppFolder:='.'+fAppFolder;

  with TSQLLog.Family do begin
    Level := [sllError, sllDebug, sllSQL, sllCache, sllResult, sllDB, sllHTTP, sllClient, sllServer];
    LevelStackTrace:=[sllNone];
    DestinationPath := 'log'+PathDelim;
    if not FileExists(DestinationPath) then  CreateDir(DestinationPath);
    //NoFile := true;
    //EchoCustom := OnLogEvent;
    EchoToConsole := LOG_VERBOSE; // log all events to the console
  end;

  Model := CreateSampleModel;

  inherited Create(Model,fRootFolder+'data.db3',False);

  CreateMissingTables;

  Server := TODataHttpServer.Create(PORT,Self);
end;

destructor TmORMotODataServer.Destroy;
begin
  Server.Free;
  if Assigned(Model) then Model.Free;
end;

end.
