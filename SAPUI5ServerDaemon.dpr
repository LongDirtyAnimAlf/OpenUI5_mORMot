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

{$define INCLUDESTATICSERVER}

uses
  {$ifdef Linux}
  cthreads,
  {$endif}
  Classes,
  SysUtils,
  SynCommons, mORMot, SynLog,
  mORMotSQLite3, SynSQLite3Static,
  mORMotHttpServer,
  {$ifdef INCLUDESTATICSERVER}
  SynCrtSock,
  {$endif}
  SampleData,
  daemonapp;

Type
  {$ifdef INCLUDESTATICSERVER}
  TCustomHttpServer = class(TSQLHttpServer)
  protected
    function Request(Ctxt: THttpServerRequest): cardinal; override;
  public
    ServerRoot:string;
  end;
  {$endif}

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

{ TCustomHttpServer }

function TCustomHttpServer.Request(Ctxt: THttpServerRequest): cardinal;
var
  FileName: TFileName;
  FN: RawUTF8;
  x:integer;
  aUserAgent: RawUTF8;
begin
  FN:='/'+UpperCase(STATICROOT)+'/';

  TSQLLog.Add.Log(sllHTTP,'Got URL request: '+Ctxt.URL);

  if (Ctxt.Method='GET')
     AND
     (IdemPChar(pointer(Ctxt.URL),pointer(FN)))
     then
  begin

      TSQLLog.Add.Log(sllHTTP,'Serving local static contents');

      FN := UrlDecode(copy(Ctxt.URL,Length(STATICROOT)+3,maxInt));

      if (DirectorySeparator<>'/')
         then FN := StringReplaceChars(FN,'/',DirectorySeparator);

      // safety first: no deep directories !!
      if PosEx('..',FN)>0 then
      begin
         result := 404;
        exit;
      end;

      while (FN<>'') and (FN[1]=DirectorySeparator) do delete(FN,1,1);

      x:=Pos('?',FN);
      if x>0 then delete(FN,x,maxInt);

      while (FN<>'') and (FN[length(FN)]=DirectorySeparator) do delete(FN,length(FN),1);

      FileName := IncludeTrailingPathDelimiter(ServerRoot)+UTF8ToString(FN);

      if DirectoryExists(FileName) then result := 404 else
      begin
        TSQLLog.Add.Log(sllHTTP,'Serving local file: '+FileName);
        Ctxt.OutContent := StringToUTF8(FileName);
        Ctxt.OutContentType := HTTP_RESP_STATICFILE;
        Ctxt.OutCustomHeaders := GetMimeContentTypeHeader('',FileName);
        result := 200;
      end;

  end else
    // call the associated TSQLRestServer instance(s)
    result := inherited Request(Ctxt);

    //aUserAgent:=FindIniNameValue(pointer(Ctxt.InHeaders),'USER-AGENT: ');
    //
    //TSQLLog.Add.Log(sllHTTP,'User agent: '+aUserAgent);

    //if (Length(aUserAgent)>0) AND (PosEx('mORMot',aUserAgent)=0) then
    //   Ctxt.OutContent := '{"results":'+Ctxt.OutContent+'}';
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
  DB := TSQLRestServerDB.Create(Model,fDataFolder+PathDelim+'data.db3',true);
  DB.CreateMissingTables;
  DB.Html200WithNoBodyReturns204:=True;
  TSQLLog.Add.Log(sllInfo,'Database started !!');

  {$ifdef INCLUDESTATICSERVER}
  Server := TCustomHttpServer.Create(PORT,[DB],'+',HTTP_DEFAULT_MODE,32,secNone,STATICROOT);
  TCustomHttpServer(Server).ServerRoot:=ExtractFilePath(ParamStr(0))+WEBROOT;
  if NOT DirectoryExists(TCustomHttpServer(Server).ServerRoot) then
     TCustomHttpServer(Server).ServerRoot:=ExtractFileDir(ParamStr(0));
  {$else}
  Server := TSQLHttpServer.Create(PORT,DB);
  {$endif}
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
