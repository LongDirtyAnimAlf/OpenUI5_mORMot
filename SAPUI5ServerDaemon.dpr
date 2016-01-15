// RESTful ORM server for OpenUI5 demo
// does not server static content
// static content is done by a standard webserver like apache or its likes
program SAPUI5ServerDaemon;

{$IFDEF LINUX}
{$IFDEF CPUX86_64}
{$IFDEF FPC_CROSSCOMPILING}
{$linklib libc_nonshared.a}
{$ENDIF}
{$ENDIF}
{$ENDIF}

uses
  {$ifdef Linux}
  cthreads,
  {$endif}
  Classes,
  SysUtils,
  SynCommons, mORMot, SynLog,
  mORMotSQLite3, SynSQLite3Static,
  mORMotHttpServer,// SynCrtSock,
  SampleData,
  daemonapp;

Type
  { TTestDaemon }

  TTestDaemon = Class(TCustomDaemon)
  Private
    Model: TSQLModel;
    DB: TSQLRestServerDB;
    Server: TSQLHttpServer;
  public
    Function Start : Boolean; override;
    Function Stop : Boolean; override;
    Function Pause : Boolean; override;
    Function Continue : Boolean; override;
    Function Execute : Boolean; override;
    Function ShutDown : Boolean; override;
    Function Install : Boolean; override;
    Function UnInstall: boolean; override;
  end;

Procedure AWriteln(MSg : String; B : Boolean);
begin
  Application.Log(etcustom,Msg+BoolToStr(B));
end;

{ TTestDaemon }

function TTestDaemon.Start: Boolean;
var
  fDataFolder:string;
begin
  Result:=inherited Start;

  AWriteln('Daemon Start',Result);

  if not DirectoryExists(GetAppConfigDir(False)) then CreateDir(GetAppConfigDir(False));

  fDataFolder := EnsureDirectoryExists(GetAppConfigDir(False)+PathDelim+'data',true);

  AWriteln('Dir: '+fDataFolder,True);

  with TSQLLog.Family do begin
    Level := [sllInfo, sllError, sllDebug, sllSQL, sllCache, sllResult, sllDB, sllHTTP, sllClient, sllServer];
    LevelStackTrace:=[sllNone];
    DestinationPath := fDataFolder+PathDelim+'log';
    if not FileExists(DestinationPath) then  CreateDir(DestinationPath);
  end;

  Model := CreateSampleModel;
  TSQLLog.Add.Log(sllInfo,'Model created !!');

  TSQLLog.Add.Log(sllInfo,'Database file at '+fDataFolder+PathDelim+'data.db3');
  DB := TSQLRestServerDB.Create(Model,fDataFolder+PathDelim+'data.db3',false);
  DB.CreateMissingTables;
  DB.Html200WithNoBodyReturns204:=True;
  TSQLLog.Add.Log(sllInfo,'Database started !!');

  Server := TSQLHttpServer.Create(PORT,DB);
  Server.AccessControlAllowOrigin := '*'; // allow cross-site AJAX queries
  TSQLLog.Add.Log(sllInfo,'Webserver started !!');
  TSQLLog.Add.Log(sllInfo,'Webserver listening on '+PORT);
end;

function TTestDaemon.Stop: Boolean;
begin
  Result:=inherited Stop;
  AWriteln('Daemon Stop: ',Result);
  FreeAndNil(Server);
  TSQLLog.Add.Log(sllInfo,'Webserver stopped.');
  FreeAndNil(DB);
  TSQLLog.Add.Log(sllInfo,'Database stopped.');
  FreeAndNil(Model);
  TSQLLog.Add.Log(sllInfo,'Model destroyed.');
end;

function TTestDaemon.Pause: Boolean;
begin
  Result:=inherited Pause;
  AWriteln('Daemon pause: ',Result);
end;

function TTestDaemon.Continue: Boolean;
begin
  Result:=inherited Continue;
  AWriteln('Daemon continue: ',Result);
end;

function TTestDaemon.Execute: Boolean;
begin
  Result:=inherited Execute;
  AWriteln('Daemon execute: ',Result);
end;

function TTestDaemon.ShutDown: Boolean;
begin
  Result:=inherited ShutDown;
  AWriteln('Daemon Shutdown: ',Result);
  FreeAndNil(Server);
  FreeAndNil(DB);
  FreeAndNil(Model);
end;

function TTestDaemon.Install: Boolean;
begin
  Result:=inherited Install;
  AWriteln('Daemon Install: ',Result);
end;

function TTestDaemon.UnInstall: boolean;
begin
  Result:=inherited UnInstall;
  AWriteln('Daemon UnInstall: ',Result);
end;

Type

  { TTestDaemonMapper }

  TTestDaemonMapper = Class(TCustomDaemonMapper)
    Constructor Create(AOwner : TComponent); override;
  end;

{ TTestDaemonMapper }

constructor TTestDaemonMapper.Create(AOwner: TComponent);

Var
  D : TDaemonDef;

begin
  inherited Create(AOwner);
  D:=DaemonDefs.Add as TDaemonDef;
  D.DisplayName:='Test daemon';
  D.Name:='TestDaemon';
  D.DaemonClassName:='TTestDaemon';
  //D.WinBindings.ServiceType:=stWin32;
end;

begin
  RegisterDaemonClass(TTestDaemon);
  RegisterDaemonMapper(TTestDaemonMapper);
  Application.Run;
end.
