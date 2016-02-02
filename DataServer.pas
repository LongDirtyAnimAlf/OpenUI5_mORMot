unit dataserver;

{$I Synopse.inc}

{$define METADATAV2}

interface

uses
  {$ifdef Darwin}
  Unix,
  {$endif}
  SysUtils, Classes,
  SynCommons, mORMot,
  mORMotSQLite3, SynSQLite3Static,
  mORMotHttpServer, SynCrtSock,
  SampleData;

{$ifdef METADATAV2}
const
  INT64TYPE = '"Edm.Int32"';
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
{$else}
const
  INT64TYPE = '"Edm.Int64"';
  __TMetaData =
  'Edmx_placeholder {'+
     'DataServices_placeholder{'+
        'Schema{'+
           'EntityType ['+
             'Key{'+
               'PropertyRef RawUTF8 '+
             '}'+
             'Property_placeholder array of RawUTF8 '+
             'NavigationProperty array of RawUTF8 '+
           '] '+
           'EntityContainer{'+
             'EntitySet array of RawUTF8 '+
           '} '+
           'Annotations ['+
             'Annotation RawUTF8 '+
           '] '+
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
          Annotations: array of packed record
            Annotation: RawUTF8;
          end;
        end;
      end;
    end;
  end;
  {$endif}

  TCustomHttpServer = class(TSQLHttpServer)
  protected
    function Request(Ctxt: THttpServerRequest): cardinal; override;
  public
    ServerRoot:string;
    {$ifndef METADATAV2}
    MustEncapsulate:boolean;
    {$endif}
  end;

  TmORMotODataServer = class(TSQLRestServerDB)
  private
    Model:TSQLModel;
    MetaData:RawUTF8;
    function BeforeUri(Ctxt: TSQLRestServerURIContext): boolean;
    procedure AfterUri(Ctxt: TSQLRestServerURIContext);
  protected
    fRootFolder: TFileName;
    fDataFolder: TFileName;
    fAppFolder: TFileName;
  public
    Server: TCustomHttpServer;
    constructor Create(const aRootFolder: TFileName=''; const aRootURI: RawUTF8='root'); reintroduce;
    destructor Destroy; override;
  end;

implementation

uses
  SynLog;


function TmORMotODataServer.BeforeUri(Ctxt: TSQLRestServerURIContext): boolean;
var
  pParameters:PUTF8Char;
  Count,Top,FN: RawUTF8;
  bUriHandled:boolean;
  {$ifdef METADATAV2}
  x:integer;
  aCount:Int64;
  {$endif}
begin
  // Here, we get the real (ORM) requests !!
  // Process them, if needed.

  if (Length(URIPagingParameters.SendTotalRowsCountFmt)>0) then URIPagingParameters.SendTotalRowsCountFmt := '';

  bUriHandled:=false;

  if Ctxt.ClientKind=ckAJAX then
  begin
    {$ifndef METADATAV2}
    Server.MustEncapsulate:=true;
    {$endif}

    TSQLLog.Add.Log(sllHTTP,'Got new URI:  '+Ctxt.URI);
    TSQLLog.Add.Log(sllHTTP,'Got new URL:  '+Ctxt.Call^.Url);

    if ((NOT bUriHandled) AND (Ctxt.Method=mGET)) then
    begin
      FN:=UpperCase(Model.Root)+'/$METADATA';
      if (IdemPChar(pointer(Ctxt.Call^.Url),pointer(FN))) then
      begin
        TSQLLog.Add.Log(sllHTTP,'Got metadata request URL:  '+Ctxt.Call^.Url);
        TSQLLog.Add.Log(sllHTTP,'Sending metadata to this URL');
        Ctxt.Call^.OutBody:=MetaData;
        // important !!!!
        // OpenUI5 needs this header for $metadata
        Ctxt.Call^.OutHead:=HEADER_CONTENT_TYPE+'application/xml'+
        #13#10'Access-Control-Allow-Origin:*'+
        #13#10'Access-Control-Allow-Methods: POST, PUT, GET, DELETE, LOCK, OPTIONS';
        //#13#10'Access-Control-Allow-Headers: origin, x-requested-with, content-type'
        Ctxt.Call^.OutStatus := 200;
        bUriHandled:=true;
      end;
    end;

    {$ifdef METADATAV2}
    if ((NOT bUriHandled) AND (Ctxt.Method=mGET)) then
    begin
      for x:=0 to high(Model.Tables) do
      begin
        FN:=UpperCase(Model.Root)+'/'+UpperCase(Model.Tables[x].SQLTableName)+'/$COUNT';
        if (IdemPChar(pointer(Ctxt.Call^.Url),pointer(FN))) then
        begin
          aCount:=0;
          OneFieldValue(Model.Tables[x], 'COUNT(*)','',[],[],aCount);
          TSQLLog.Add.Log(sllHTTP,'Got V2 count request URL:  '+Ctxt.Call^.Url);
          TSQLLog.Add.Log(sllHTTP,'Sending record count to this URL');
          Ctxt.Call^.OutBody:=InttoStr(aCount);
          Ctxt.Call^.OutHead:=HEADER_CONTENT_TYPE+TEXT_CONTENT_TYPE+
          #13#10'Access-Control-Allow-Origin:*'+
          #13#10'Access-Control-Allow-Methods: POST, PUT, GET, DELETE, LOCK, OPTIONS';
          //#13#10'Access-Control-Allow-Headers: origin, x-requested-with, content-type'
          Ctxt.Call^.OutStatus := 200;
          bUriHandled:=true;
          break
        end;
      end;
    end;
    {$endif}

    // process count of results if asked for
    if ((NOT bUriHandled) AND (Ctxt.Method=mGET)) then
    begin
      pParameters:=Ctxt.Parameters;
      if pParameters<>nil then
      begin

        Count:='';
        Top:='';

        if pParameters^<>#0 then
        repeat
          {$ifdef METADATAV2}
          UrlDecodeValue(pParameters,'$INLINECOUNT=',Count);
          {$else}
          UrlDecodeValue(pParameters,'$COUNT=',Count);
          {$endif}
          UrlDecodeValue(pParameters,URIPagingParameters.Results,Top,@pParameters);
        until pParameters=nil;

        if (Length(Count)>0) AND {$ifdef METADATAV2} (IdemPChar(pointer(Count),'ALLPAGES')) {$else} ((IdemPChar(pointer(Count),'TRUE'))) {$endif} then
        begin
          {$ifdef METADATAV2}
          URIPagingParameters.SendTotalRowsCountFmt :=',"__count":"%"';
          //mORMot feature request ... not yet available
          //aServer.URIPagingParameters.EncapsulateResultFmt := '"results"';
          {$else}
          Server.MustEncapsulate:=False;
          URIPagingParameters.SendTotalRowsCountFmt :=',"@odata.count":%';
          //mORMot feature request ... not yet available
          //aServer.URIPagingParameters.EncapsulateResultFmt := '"value"';
          {$endif}
          if Top='' then
          begin
            // Must add URIPagingParameters.Results: without it, the mORMot does not return results
            // Kind of a hack
            Ctxt.Call^.Url:=Ctxt.Call^.Url+'&$top='+InttoStr(MaxInt);
            // Due to new Url, (that creates a new string), the Parameters and ParametersPos have to be set anew !
            // Kind of a dirty hack
            Ctxt.ParametersPos := PosEx(RawUTF8('?'),Ctxt.Call^.url,1);
            if Ctxt.ParametersPos>0 then // '?select=...&where=...' or '?where=...'
               Ctxt.Parameters := @Ctxt.Call^.url[Ctxt.ParametersPos+1];
          end;
        end;
      end;
    end;
  end;

  TSQLLog.Add.Log(sllHTTP,'Got new URL:  '+Ctxt.Call^.Url);

  //execute command if necessary
  result:=(NOT bUriHandled);
end;

procedure TmORMotODataServer.AfterUri(Ctxt: TSQLRestServerURIContext);
var
  FN:RawUTF8;
begin
  TSQLLog.Add.Log(sllHTTP,'Set new URI:  '+Ctxt.URI);
  TSQLLog.Add.Log(sllHTTP,'Set new URL:  '+Ctxt.Call^.Url);


  if Ctxt.ClientKind=ckAJAX then
  begin
    if (Length(URIPagingParameters.SendTotalRowsCountFmt)>0) then
    begin
      //mORMot feature request ... not yet available, so this work-around ... see above
      {$ifdef METADATAV2}
      // values must become results
      Ctxt.Call^.OutBody:=StringReplace(Ctxt.Call^.OutBody,'{"values":','{"results":',[]);
      {$else}
      // values must become value
      Ctxt.Call^.OutBody:=StringReplace(Ctxt.Call^.OutBody,'{"values":','{"value":',[]);
      {$endif}
    end;

    FN:='APPLICATION/JSON';
    if ((IdemPChar(pointer(Ctxt.Call^.OutBodyType),pointer(FN))) AND (Length(Ctxt.Call^.OutBody)>0)) then
    // results must be encapsulated
    {$ifdef METADATAV2}
    Ctxt.Call^.OutBody := '{"d":'+Ctxt.Call^.OutBody+'}';
    {$else}
    if Server.MustEncapsulate then Ctxt.Call^.OutBody := '{"value":'+Ctxt.Call^.OutBody+'}';
    {$endif}
  end;
end;

constructor TmORMotODataServer.Create(const aRootFolder: TFileName; const aRootURI: RawUTF8);
var
  x,y:integer;
  aMetaData:TMetaData;
  FN: RawUTF8;
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
  Self.Options:=[rsoGetAsJsonNotAsString,rsoHtml200WithNoBodyReturns204,rsoAddUpdateReturnsContent,rsoComputeFieldsBeforeWriteOnServerSide];

  // adapted for OpenUI5
  URIPagingParameters.Select                := '$SELECT=';
  URIPagingParameters.StartIndex            := '$SKIP=';
  URIPagingParameters.Results               := '$TOP=';
  URIPagingParameters.Sort                  := '$ORDERBY=';
  URIPagingParameters.Where                 := '$FILTER=';

  Server := TCustomHttpServer.Create(PORT,[Self],'+',HTTP_DEFAULT_MODE,32,secNone,STATICROOT);
  Server.AccessControlAllowOrigin := '*'; // allow cross-site AJAX queries

  TCustomHttpServer(Server).ServerRoot:=ExtractFilePath(ParamStr(0))+WEBROOT;

  if NOT DirectoryExists(TCustomHttpServer(Server).ServerRoot) then
     TCustomHttpServer(Server).ServerRoot:=ExtractFileDir(ParamStr(0));

  OnBeforeURI:=BeforeUri;
  OnAfterURI:=AfterUri;

  TSQLLog.Add.Log(sllHTTP,'making Metadata !!');

  SetLength(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType,length(Model.Tables));
  SetLength(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityContainer.EntitySet,length(Model.Tables));

  for x := 0 to high(Model.Tables) do
  begin
    // setting of key .... for mORMot always ID
    aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].Key.PropertyRef:='Name="ID"';

    //SetLength(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].Property_placeholder,Model.Tables[x].RecordProps.Fields.Count+1);
    //aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].Property_placeholder[0]:='Name="ID" Nullable="false" Type='+INT64TYPE;

    // setting of fields
    SetLength(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].Property_placeholder,1);
    aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].Property_placeholder[0]:='Name="ID" Nullable="false" Type='+INT64TYPE;
    for y := 1 to (Model.Tables[x].RecordProps.Fields.Count) do
    begin

      if Model.Tables[x].RecordProps.Fields.Items[y-1].SQLFieldType=sftTID then continue;
      if Model.Tables[x].RecordProps.Fields.Items[y-1].SQLFieldType=sftID then continue;

      // coarse setting of type
      case Model.Tables[x].RecordProps.Fields.Items[y-1].SQLDBFieldType of
        ftNull:     FN := '"Null"';
        ftInt64:    FN := INT64TYPE;
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
      case Model.Tables[x].RecordProps.Fields.Items[y-1].SQLFieldType of
        sftBoolean:   FN := '"Edm.Boolean"';
        sftInteger:   FN := '"Edm.Int32"';
        sftEnumerate: FN := '"Edm.Int16"';
        sftSet:       FN := '"Edm.Int16"';
      end;
      // UTF8 array:
      //FN:='"Collection(Edm.String)"';

      SetLength(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].Property_placeholder,Length(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].Property_placeholder)+1);
      FN:='Name="'+Model.Tables[x].RecordProps.Fields.Items[y-1].Name+'" Type='+FN+' Nullable="true" sap:updatable="true"';
      if (Model.Tables[x].RecordProps.Fields.Items[y-1].SQLDBFieldType=ftBlob) OR (Model.Tables[x].RecordProps.Fields.Items[y-1].Name='PictureUrl')
         then FN:=FN+' sap:sortable="false" sap:filterable="false" sap:creatable="false"'
         else FN:=FN+' sap:sortable="true" sap:filterable="true" sap:creatable="true"';
      if Model.Tables[x].RecordProps.Fields.Items[y-1].FieldWidth>0 then FN:=FN+' MaxLength="'+InttoStr(Model.Tables[x].RecordProps.Fields.Items[y-1].FieldWidth)+'"';
      aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].Property_placeholder[High(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].Property_placeholder)]:=FN;

    end;

    // do the navigation properties : mORMot joined tables !!
    for y := 1 to Length(Model.Tables[x].RecordProps.JoinedFields) do
    begin

      {$ifdef METADATAV2}
      FN:=
          'Name="'+Model.Tables[x].RecordProps.JoinedFields[y-1].Name+'"'+
          ' ToRole="'+Model.Tables[x].RecordProps.JoinedFieldsTable[y].SQLTableName+'"'+
          ' FromRole="'+Model.Tables[x].SQLTableName+'"'+
          ' Relationship="mORMot.FK_'+Model.Tables[x].RecordProps.JoinedFieldsTable[y].SQLTableName+'_'+Model.Tables[x].SQLTableName+'"';
      {$else}
      FN:=
        'Name="'+Model.Tables[x].RecordProps.JoinedFields[y-1].Name+'"'+
        ' Type="mORMot.'+Model.Tables[x].RecordProps.JoinedFieldsTable[y].SQLTableName+'"';//+
        //' Partner="Members"';
      {$endif}
      SetLength(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].NavigationProperty,Length(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].NavigationProperty)+1);
      aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].NavigationProperty[High(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].NavigationProperty)]:=FN;
    end;

    // setting of entityset
    if (Model.Tables[x].InheritsFrom(TSQLAuthUser)) OR (Model.Tables[x].InheritsFrom(TSQLAuthGroup))
       then FN:='sap:creatable="false" sap:updatable="true" sap:deletable="false"'
       else FN:='sap:creatable="true" sap:updatable="true" sap:deletable="true"';
    aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityContainer.EntitySet[x]:=
      'Name="'+Model.Tables[x].SQLTableName+'"'+
      ' EntityType="mORMot.'+Model.Tables[x].SQLTableName+'"'+
      ' sap:pageable="true" sap:content-version="1" '+FN;
  end;

  {$ifndef METADATAV2}
  SetLength(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.Annotations,3);
  aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.Annotations[0].Annotation:='Term="Org.OData.Display.V1.Description" String="This is a sample mORMot OData service"';
  aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.Annotations[1].Annotation:='Term="Org.OData.Display.V1.Description" String="All teams"';
  aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.Annotations[2].Annotation:='Term="Org.OData.Display.V1.Description" String="All members"';
  {$endif}

  FN := RecordSaveJSON(aMetaData,TypeInfo(TMetaData));

  JSONBufferToXML(pointer(FN),XMLUTF8_HEADER,'',MetaData);

  {$ifdef METADATAV2}
  MetaData:=StringReplace(MetaData,'<Edmx_placeholder>','<edmx:Edmx xmlns:edmx="http://schemas.microsoft.com/ado/2007/06/edmx" Version="1.0">',[]);
  MetaData:=StringReplace(MetaData,'<DataServices_placeholder>','<edmx:DataServices xmlns:m="http://schemas.microsoft.com/ado/2007/08/dataservices/metadata" m:MaxDataServiceVersion="3.0" m:DataServiceVersion="1.0">',[]);
  MetaData:=StringReplace(MetaData,'<Schema>','<Schema xmlns="http://schemas.microsoft.com/ado/2009/11/edm" Namespace="mORMot" xml:lang="en">',[]);
  {$else}
  MetaData:=StringReplace(MetaData,'<Edmx_placeholder>','<edmx:Edmx xmlns:edmx="http://docs.oasis-open.org/odata/ns/edmx" Version="4.0">',[]);
  MetaData:=StringReplace(MetaData,'DataServices_placeholder','edmx:DataServices',[rfReplaceAll]);
  MetaData:=StringReplace(MetaData,'<Schema>','<Schema xmlns="http://docs.oasis-open.org/odata/ns/edm" Namespace="mORMot">',[]);
  {$endif}


  MetaData:=StringReplace(MetaData,'</Edmx_placeholder>','</edmx:Edmx>',[]);

  MetaData:=StringReplace(MetaData,'</DataServices_placeholder>','</edmx:DataServices>',[]);


  MetaData:=StringReplace(MetaData,'<Property_placeholder>','<Property ',[rfReplaceAll]);
  MetaData:=StringReplace(MetaData,'</Property_placeholder>',' />',[rfReplaceAll]);

  MetaData:=StringReplace(MetaData,'<PropertyRef>','<PropertyRef ',[rfReplaceAll]);
  MetaData:=StringReplace(MetaData,'</PropertyRef>',' />',[rfReplaceAll]);

  MetaData:=StringReplace(MetaData,'<NavigationProperty>','<NavigationProperty ',[rfReplaceAll]);
  MetaData:=StringReplace(MetaData,'</NavigationProperty>',' />',[rfReplaceAll]);

  {$ifndef METADATAV2}
  MetaData:=StringReplace(MetaData,'<Annotations>','<Annotations Target="mORMot.mORMotService">',[]);
  MetaData:=StringReplace(MetaData,'<Annotations>','<Annotations Target="mORMot.Team">',[]);
  MetaData:=StringReplace(MetaData,'<Annotations>','<Annotations Target="mORMot.Member">',[]);

  MetaData:=StringReplace(MetaData,'<Annotation>','<Annotation ',[rfReplaceAll]);
  MetaData:=StringReplace(MetaData,'</Annotation>',' />',[rfReplaceAll]);
  {$endif}


  // this is a bit tricky ...
  // everytime an <EntityType> is encountered, it is replaced by <EntityType with table name>
  // works because of the sequence of creating this (see above) ... but still tricky
  for x := 0 to high(Model.Tables) do
  begin
    {$ifdef METADATAV2}
    MetaData:=StringReplace(MetaData,'<EntityType>','<EntityType Name="'+Model.Tables[x].SQLTableName+'"'+
           ' Namespace="mORMot" EntityType="mORMot.'+Model.Tables[x].SQLTableName+'"'+
           ' xmlns:sap="http://www.sap.com/Protocols/SAPData"'+
           ' sap:content-version="1"'+
           '>',[]);
    {$else}
    MetaData:=StringReplace(MetaData,'<EntityType>','<EntityType Name="'+Model.Tables[x].SQLTableName+'"'+
           ' xmlns:sap="http://www.sap.com/Protocols/SAPData">',[]);
    {$endif}
  end;

  {$ifdef METADATAV2}
  MetaData:=StringReplace(MetaData,'<EntityContainer>','<EntityContainer Name="mORMotService" xmlns:sap="http://www.sap.com/Protocols/SAPData" m:IsDefaultEntityContainer="true">',[]);
  {$else}
  MetaData:=StringReplace(MetaData,'<EntityContainer>','<EntityContainer Name="mORMotService" xmlns:sap="http://www.sap.com/Protocols/SAPData">',[]);
  {$endif}

  MetaData:=StringReplace(MetaData,'<EntitySet>','<EntitySet ',[rfReplaceAll]);
  MetaData:=StringReplace(MetaData,'</EntitySet>',' />',[rfReplaceAll]);

  MetaData:=StringReplace(MetaData,'&quot;','"',[rfReplaceAll]);

end;

destructor TmORMotODataServer.Destroy;
begin
  Server.Free;
  Model.Free;
end;

{ TCustomHttpServer }



function TCustomHttpServer.Request(Ctxt: THttpServerRequest): cardinal;
var
  FileName: TFileName;
  FN: RawUTF8;
  x:integer;
begin

  TSQLLog.Add.Log(sllHTTP,'Got URL:  '+Ctxt.URL+', with method: '+Ctxt.Method);

  FN:='/'+UpperCase(STATICROOT)+'/';

  if ( IdemPChar(pointer(Ctxt.URL),pointer(FN)) OR IdemPChar(pointer(Ctxt.URL),'/FAVICON.ICO') )  then
  begin
    // serve static contents
    if (Ctxt.Method='GET') then
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
    end;
  end
  else
  begin
    // serve all other contents
    TSQLLog.Add.Log(sllHTTP,'Performing inherited with URL: '+Ctxt.URL);
    result := inherited Request(Ctxt);
    TSQLLog.Add.Log(sllHTTP,'Performing inherited done with URL: '+Ctxt.URL);
    TSQLLog.Add.Log(sllHTTP,'Sending result: '+Ctxt.OutContent);
  end;
end;

initialization
  TTextWriter.RegisterCustomJSONSerializerFromText(
    TypeInfo(TMetaData),__TMetaData);

end.
