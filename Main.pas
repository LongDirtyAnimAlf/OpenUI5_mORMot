unit Main;

interface

uses
  {$ifdef MSWINDOWS}
  Windows,
  Messages,
  {$endif}
  {$ifdef Darwin}
  Unix,
  {$endif}
  SysUtils, Classes, Controls,
  Forms, StdCtrls, Dialogs,
  SynCommons, mORMot,
  mORMotSQLite3, SynSQLite3Static,
  mORMotHttpServer, SynCrtSock,
  SampleData;

type
  TCustomHttpServer = class(TSQLHttpServer)
  protected
    function Request(Ctxt: THttpServerRequest): cardinal; override;
  end;


  { TForm1 }

  TForm1 = class(TForm)
    btnOpen: TButton;
    btnRoot: TButton;
    Label1: TLabel;
    Button1: TButton;
    Label2: TLabel;
    Memo1: TMemo;
    OpenDialog1: TOpenDialog;
    procedure btnOpenClick(Sender: TObject);
    procedure btnRootClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    function OnLogEvent(Sender: TTextWriter; Level: TSynLogInfo;
      const Text: RawUTF8):boolean;
  public
    Model: TSQLModel;
    DB: TSQLRestServerDB;
    Server: TSQLHttpServer;
  end;



var
  Form1: TForm1;
  ServerRoot:string;

implementation

{$R *.lfm}

{$ifdef FPC}
uses
  LCLIntf; // for OpenURL
{$endif}

{ TForm1 }

function TForm1.OnLogEvent(Sender: TTextWriter; Level: TSynLogInfo;
      const Text: RawUTF8):boolean;
begin
  result:=True;
  Memo1.Lines.Append(Text);
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  Close;
end;

procedure TForm1.btnOpenClick(Sender: TObject);
begin
  {$ifdef Windows}
  ShellExecute(0,'open',pointer('http://'+HOST+':'+PORT+'/'+STATICROOT+'/'+INDEXFILE),
      nil,nil,SW_SHOWNORMAL);
  {$else}
  OpenURL('http://'+HOST+':'+PORT+'/'+STATICROOT+'/'+INDEXFILE);
  {$endif}
end;

procedure TForm1.btnRootClick(Sender: TObject);
begin
  if OpenDialog1.Execute then
  begin
    ServerRoot:=ExtractFileDir(OpenDialog1.FileName);
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin

  with TSQLLog.Family do begin
    Level := [sllError, sllDebug, sllSQL, sllCache, sllResult, sllDB, sllHTTP, sllClient, sllServer];
    LevelStackTrace:=[sllNone];
    DestinationPath := 'log'+PathDelim;
    if not FileExists(DestinationPath) then  CreateDir(DestinationPath);
    //NoFile := true;
    EchoCustom := OnLogEvent;
  end;

  Model := CreateSampleModel;
  DB := TSQLRestServerDB.Create(Model,ChangeFileExt(ExeVersion.ProgramFileName,'.db3'),false);
  DB.CreateMissingTables;
  DB.Html200WithNoBodyReturns204:=True;

  //DB.URIPagingParameters.SendTotalRowsCountFmt := ',"_next":%';
  //DB.URIPagingParameters.Select := '$select';
  //DB.NoAJAXJSON := false;

  Server := TCustomHttpServer.Create(PORT,[DB],'+',HTTP_DEFAULT_MODE,32,secNone,STATICROOT);
  Server.AccessControlAllowOrigin := '*'; // allow cross-site AJAX queries


  ServerRoot:=ExtractFilePath(ParamStr(0))+WEBROOT;

  if NOT DirectoryExists(ServerRoot) then
     ServerRoot:=ExtractFileDir(ParamStr(0));

  //if NOT FileExists(ServerRoot+DirectorySeparator+INDEXFILE) then
  //   ServerRoot:=ExtractFileDir(ParamStr(0));

  OpenDialog1.InitialDir:=ServerRoot;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  Server.Free;
  DB.Free;
  Model.Free;
end;

procedure TForm1.FormShow(Sender: TObject);
begin
  Label1.Caption := Caption;
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

  //TSQLLog.Add.Log(sllHTTP,'Got URL request: '+Ctxt.URL);

  if (Ctxt.Method='GET')
     AND
     (IdemPChar(pointer(Ctxt.URL),pointer(FN)))
     then
  begin

      //TSQLLog.Add.Log(sllHTTP,'Serving local static contents');

      if (DirectorySeparator<>'/')
         then FN := StringReplaceChars(UrlDecode(copy(Ctxt.URL,Length(STATICROOT)+3,maxInt)),'/',DirectorySeparator);

      // safety first: no deep directories !!
      //if PosEx('..',FN)>0 then
      //begin
      //   result := 404;
      //  exit;
      //end;

      while (FN<>'') and (FN[1]=DirectorySeparator) do delete(FN,1,1);

      x:=Pos('?',FN);
      if x>0 then delete(FN,x,maxInt);

      while (FN<>'') and (FN[length(FN)]=DirectorySeparator) do delete(FN,length(FN),1);

      FileName := IncludeTrailingPathDelimiter(ServerRoot)+UTF8ToString(FN);

      if DirectoryExists(FileName) then result := 404 else
      begin
        //TSQLLog.Add.Log(sllHTTP,'Serving local file: '+FileName);
        Ctxt.OutContent := StringToUTF8(FileName);
        Ctxt.OutContentType := HTTP_RESP_STATICFILE;
        Ctxt.OutCustomHeaders := GetMimeContentTypeHeader('',FileName);
        result := 200;
      end;

  end else
    // call the associated TSQLRestServer instance(s)
    result := inherited Request(Ctxt);

    aUserAgent:=FindIniNameValue(pointer(Ctxt.InHeaders),'USER-AGENT: ');
    //
    TSQLLog.Add.Log(sllHTTP,'User agent: '+aUserAgent);

    //if (Length(aUserAgent)>0) AND (PosEx('mORMot',aUserAgent)=0) then
    //   Ctxt.OutContent := '{"results":'+Ctxt.OutContent+'}';
end;

end.
