unit Main;

{$I Synopse.inc}

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

const
  __TMetaData =
  'Edmx_placeholder {'+
     'DataServices_placeholder{'+
        'Schema{'+
           'EntityType ['+
             'Key{'+
               'PropertyRef RawUTF8'+
             '}'+
             'Property_placeholder array of RawUTF8 '+
             'NavigationProperty array of RawUTF8 '+
           '] '+
           'EntityContainer{'+
             'EntitySet array of RawUTF8 '+
           '} '+
        '} '+
     '} '+
  '}';

type
  TMetaData = packed record
    Edmx_placeholder: record
      DataServices_placeholder: record
        Schema: record
          EntityType: array of packed record
            Key: record
              PropertyRef : RawUTF8;
            end;
            Property_placeholder: array of RawUTF8;
            NavigationProperty: array of RawUTF8;
          end;
          EntityContainer: record
            EntitySet: array of RawUTF8;
          end;
        end;
      end;
    end;
  end;

  TCustomHttpServer = class(TSQLHttpServer)
  protected
    function Request(Ctxt: THttpServerRequest): cardinal; override;
  public
    ServerRoot:string;
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

implementation

{$ifdef FPC}
{$R *.lfm}
{$else}
{$R *.dfm}
{$endif}

uses
  {$ifdef FPC}
  LCLIntf; // for OpenURL
  {$else}
  ShellApi;
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
  {$ifdef MSWINDOWS}
  ShellExecute(0,'open','http://'+HOST+':'+PORT+'/'+STATICROOT+'/'+INDEXFILE,
      nil,nil,SW_SHOWNORMAL);
  {$else}
  {$ifdef FPC}
  OpenURL('http://'+HOST+':'+PORT+'/'+STATICROOT+'/'+INDEXFILE);
  {$endif}
  {$endif}
end;

procedure TForm1.btnRootClick(Sender: TObject);
begin
  if OpenDialog1.Execute then
  begin
    TCustomHttpServer(Server).ServerRoot:=ExtractFileDir(OpenDialog1.FileName);
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  x:integer;
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
  DB := TSQLRestServerDB.Create(Model,ChangeFileExt(ExeVersion.ProgramFileName,'.db3'),true);
  DB.CreateMissingTables;
  DB.Html200WithNoBodyReturns204:=True;

  // adapted for OpenUI5
  DB.URIPagingParameters.Select        := '$SELECT=';
  DB.URIPagingParameters.StartIndex    := '$SKIP=';
  DB.URIPagingParameters.Results       := '$TOP=';
  DB.URIPagingParameters.Sort          := '$ORDERBY=';
  DB.URIPagingParameters.Where         := '$FILTER=';

  Server := TCustomHttpServer.Create(PORT,[DB],'+',HTTP_DEFAULT_MODE,32,secNone,STATICROOT);
  Server.AccessControlAllowOrigin := '*'; // allow cross-site AJAX queries

  TCustomHttpServer(Server).ServerRoot:=ExtractFilePath(ParamStr(0))+WEBROOT;

  if NOT DirectoryExists(TCustomHttpServer(Server).ServerRoot) then
     TCustomHttpServer(Server).ServerRoot:=ExtractFileDir(ParamStr(0));

  OpenDialog1.InitialDir:=TCustomHttpServer(Server).ServerRoot;
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
  x,y,z:integer;
  //aUserAgent: RawUTF8;
  match:TSQLRestModelMatch;
  aModelStructure,xml: RawUTF8;
  aModel:TSQLModel;
  aCount:Int64;
  aMetaData:TMetaData;
begin

  result:=0;

  FN:='/'+UpperCase(STATICROOT)+'/';

  if (Ctxt.Method='GET')
     AND
     (IdemPChar(pointer(Ctxt.URL),pointer(FN)))
     then
  begin

      FN := UrlDecode(copy(Ctxt.URL,Length(STATICROOT)+3,maxInt));

      if (PathDelim<>'/')
         then FN := StringReplaceChars(FN,'/',PathDelim);

      // safety first: no deep directories !!
      //if PosEx('..',FN)>0 then
      //begin
      //   result := 404;
      //  exit;
      //end;

      while (FN<>'') and (FN[1]=PathDelim) do delete(FN,1,1);

      x:=Pos('?',FN);
      if x>0 then delete(FN,x,maxInt);

      while (FN<>'') and (FN[length(FN)]=PathDelim) do delete(FN,length(FN),1);

      FileName := IncludeTrailingPathDelimiter(ServerRoot)+UTF8ToString(FN);

      if DirectoryExists(FileName) then result := 404 else
      begin
        Ctxt.OutContent := StringToUTF8(FileName);
        Ctxt.OutContentType := HTTP_RESP_STATICFILE;
        Ctxt.OutCustomHeaders := GetMimeContentTypeHeader('',FileName);
        result := 200;
      end;

  end
  else
  begin
    if Ctxt.URL[1]='/' then
        FN := copy(Ctxt.URL,2,maxInt) else
        FN := Ctxt.URL;


    aCount:=-1;
    aModel:=nil;

    if (
       (Ctxt.Method='GET')
       //AND
       //(Length(Ctxt.AuthenticatedUser)>0)
       ) then
    begin
      for x := 0 to high(fDBServers) do
        with Self.fDBServers[x] do
          if Ctxt.UseSSL=(Security=secSSL) then
          begin
            match := Server.Model.URIMatch(FN);
            if match=rmNoMatch then continue;
            FN:='/'+UpperCase(Server.Model.Root)+'/$METADATA';
            if (IdemPChar(pointer(Ctxt.URL),pointer(FN))) then
            begin
              aModel:=Server.Model;
              break
            end;
            for y:=0 to high(Server.Model.Tables) do
            begin
              FN:='/'+UpperCase(Server.Model.Root)+'/'+UpperCase(Server.Model.Tables[y].SQLTableName)+'/$COUNT';
              if (IdemPChar(pointer(Ctxt.URL),pointer(FN))) then
              begin
                // handle direct !!
                aCount:=0;
                Server.OneFieldValue(Server.Model.Tables[y], 'COUNT(*)','',[],[],aCount);
                break
              end;
            end;
          end;
    end;

    if Assigned(aModel) then
    begin

      // reply with model info !!

      SetLength(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType,length(aModel.Tables));
      SetLength(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityContainer.EntitySet,length(aModel.Tables));

      for x := 0 to high(aModel.Tables) do
      begin
        // setting of key .... for mORMot always ID
        aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].Key.PropertyRef:='Name="ID"';

        //SetLength(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].Property_placeholder,aModel.Tables[x].RecordProps.Fields.Count+1);
        //aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].Property_placeholder[0]:='Name="ID" Nullable="false" Type="Edm.Int64"';

        // setting of fields
        SetLength(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].Property_placeholder,1);
        aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].Property_placeholder[0]:='Name="ID" Nullable="false" Type="Edm.Int64"';
        for y := 1 to (aModel.Tables[x].RecordProps.Fields.Count) do
        begin

          if aModel.Tables[x].RecordProps.Fields.Items[y-1].SQLFieldType=sftTID then continue;
          if aModel.Tables[x].RecordProps.Fields.Items[y-1].SQLFieldType=sftID then continue;

          // coarse setting of type
          case aModel.Tables[x].RecordProps.Fields.Items[y-1].SQLDBFieldType of
            ftNull:     FN := '"Null"';
            ftInt64:    FN := '"Edm.Int32"';
            //ftDouble:   FN := '"Edm.Double"';
            //ftCurrency: FN := '"Edm.Double"';
            //ftCurrency: FN := '"Edm.Decimal"';
            ftDate:     FN := '"Edm.DateTime"';
            ftUTF8:     FN := '"Edm.String"';
            ftBlob:     FN := '"Edm.Binary"';
          else
            FN := '"Edm.String"';
          end;

          // finetuning of type
          case aModel.Tables[x].RecordProps.Fields.Items[y-1].SQLFieldType of
            sftBoolean:   FN := '"Edm.Boolean"';
            sftInteger:   FN := '"Edm.Int32"';
            sftEnumerate: FN := '"Edm.Int16"';
            sftSet:       FN := '"Edm.Int16"';
          end;
          // UTF8 array:
          //FN:='"Collection(Edm.String)"';

          SetLength(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].Property_placeholder,Length(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].Property_placeholder)+1);
          FN:='Name="'+aModel.Tables[x].RecordProps.Fields.Items[y-1].Name+'" Type='+FN+' Nullable="true" sap:creatable="true" sap:updatable="true"';
          if aModel.Tables[x].RecordProps.Fields.Items[y-1].SQLDBFieldType=ftBlob
             then FN:=FN+' sap:sortable="false" sap:filterable="false"'
             else FN:=FN+' sap:sortable="true" sap:filterable="true"';
          if aModel.Tables[x].RecordProps.Fields.Items[y-1].FieldWidth>0 then FN:=FN+' MaxLength="'+InttoStr(aModel.Tables[x].RecordProps.Fields.Items[y-1].FieldWidth)+'"';
          aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].Property_placeholder[High(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].Property_placeholder)]:=FN;

        end;

        // do the navigation properties : mORMot joined tables !!
        for y := 1 to Length(aModel.Tables[x].RecordProps.JoinedFields) do
        begin

          // Members field in Team table hard coded for this database ... must be better in future !!
          // Can / could even be omitted
          // This reverse field Members in the Team table can also be made a nav-property in the Team table:
          // Type="Collection(mORmot.Member)"
          // todo ...


          // v2 version of nav-property ...
          FN:=
              'Name="'+aModel.Tables[x].RecordProps.JoinedFields[y-1].Name+'"'+
              ' ToRole="'+aModel.Tables[x].RecordProps.JoinedFieldsTable[y].SQLTableName+'_Members"'+
              ' FromRole="'+aModel.Tables[x].SQLTableName+'_'+aModel.Tables[x].RecordProps.JoinedFields[y-1].Name+'"'+
              ' Relationship="mORMot.'+aModel.Tables[x].SQLTableName+'_'+aModel.Tables[x].RecordProps.JoinedFields[y-1].Name+'_'+aModel.Tables[x].RecordProps.JoinedFieldsTable[y].SQLTableName+'_Members"';

          {
          // v4 version of nav-property ...
          FN:=
            'Name="'+aModel.Tables[x].RecordProps.Fields.Items[y-1].Name+'"'+
            ' Type="mORMot.'+aModel.Tables[x].RecordProps.JoinedFieldsTable[y].SQLTableName+'"'+
            ' Partner="Members"';
          }

          SetLength(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].NavigationProperty,Length(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].NavigationProperty)+1);
          aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].NavigationProperty[High(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].NavigationProperty)]:=FN;
        end;

        // setting of entityset
        if (aModel.Tables[x].InheritsFrom(TSQLAuthUser)) OR (aModel.Tables[x].InheritsFrom(TSQLAuthGroup))
           then FN:='sap:creatable="false" sap:updatable="true" sap:deletable="false"'
           else FN:='sap:creatable="true" sap:updatable="true" sap:deletable="true"';
        aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityContainer.EntitySet[x]:=
          'Name="'+aModel.Tables[x].SQLTableName+'"'+
          ' EntityType="mORMot.'+aModel.Tables[x].SQLTableName+'"'+
          ' xmlns:sap="http://www.sap.com/Protocols/SAPData"'+
          ' sap:pageable="true" sap:content-version="1" '+FN;
      end;

      aModelStructure := RecordSaveJSON(aMetaData,TypeInfo(TMetaData));

      JSONBufferToXML(pointer(aModelStructure),XMLUTF8_HEADER,'',xml);

      xml:=StringReplace(xml,'<Edmx_placeholder>','<edmx:Edmx xmlns:edmx="http://schemas.microsoft.com/ado/2007/06/edmx" Version="1.0">',[]);
      xml:=StringReplace(xml,'</Edmx_placeholder>','</edmx:Edmx>',[]);
      xml:=StringReplace(xml,'<DataServices_placeholder>','<edmx:DataServices xmlns:m="http://schemas.microsoft.com/ado/2007/08/dataservices/metadata" m:MaxDataServiceVersion="3.0" m:DataServiceVersion="1.0">',[]);
      xml:=StringReplace(xml,'</DataServices_placeholder>','</edmx:DataServices>',[]);
      xml:=StringReplace(xml,'<Schema>','<Schema xmlns="http://schemas.microsoft.com/ado/2009/11/edm" Namespace="mORMot" xml:lang="en">',[]);

      xml:=StringReplace(xml,'<Property_placeholder>','<Property ',[rfReplaceAll]);
      xml:=StringReplace(xml,'</Property_placeholder>',' />',[rfReplaceAll]);

      xml:=StringReplace(xml,'<PropertyRef>','<PropertyRef ',[rfReplaceAll]);
      xml:=StringReplace(xml,'</PropertyRef>',' />',[rfReplaceAll]);

      xml:=StringReplace(xml,'<NavigationProperty>','<NavigationProperty ',[rfReplaceAll]);
      xml:=StringReplace(xml,'</NavigationProperty>',' />',[rfReplaceAll]);


      // this is a bit tricky ...
      // everytime an <EntityType> is encountered, it is replaced by <EntityType with table name>
      // works because of the sequence of creating this (see above) ... but still tricky
      for x := 0 to high(aModel.Tables) do
      begin
        xml:=StringReplace(xml,'<EntityType>','<EntityType Name="'+aModel.Tables[x].SQLTableName+'"'+
               ' Namespace="mORMot" EntityType="mORMot.'+aModel.Tables[x].SQLTableName+'"'+
               ' xmlns:sap="http://www.sap.com/Protocols/SAPData"'+
               ' sap:content-version="1"'+
               '>',[]);
      end;

      xml:=StringReplace(xml,'<EntityContainer>','<EntityContainer Name="mORMotService" m:IsDefaultEntityContainer="true">',[]);

      xml:=StringReplace(xml,'<EntitySet>','<EntitySet ',[rfReplaceAll]);
      xml:=StringReplace(xml,'</EntitySet>',' />',[rfReplaceAll]);

      xml:=StringReplace(xml,'&quot;','"',[rfReplaceAll]);

      Ctxt.OutContent := xml;
      // important !!!!
      // OpenUI5 needs this header for $metadata
      Ctxt.OutContentType := 'application/xml';
      Ctxt.OutCustomHeaders:='Access-Control-Allow-Origin:*'+
      #13#10'Access-Control-Allow-Methods: POST, PUT, GET, DELETE, LOCK, OPTIONS';
      //#13#10'Access-Control-Allow-Headers: origin, x-requested-with, content-type'
      result := 200;
    end;

    if (aCount>-1) then
    begin
      Ctxt.OutContent := InttoStr(aCount);
      Ctxt.OutContentType := TEXT_CONTENT_TYPE;
      Ctxt.OutCustomHeaders:='Access-Control-Allow-Origin:*'+
      #13#10'Access-Control-Allow-Methods: POST, PUT, GET, DELETE, LOCK, OPTIONS';
      //#13#10'Access-Control-Allow-Headers: origin, x-requested-with, content-type'
      result := 200;
    end;

    if result=0 then
      // call the associated TSQLRestServer instance(s)
      result := inherited Request(Ctxt);
  end;
end;

initialization
  TTextWriter.RegisterCustomJSONSerializerFromText(
    TypeInfo(TMetaData),__TMetaData);

end.
