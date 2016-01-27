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
    MetaData:RawUTF8;
    ServerRoot:string;
  end;

  TmORMotODataServer = class(TSQLRestServerDB)
  private
    Model:TSQLModel;
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

constructor TmORMotODataServer.Create(const aRootFolder: TFileName; const aRootURI: RawUTF8);
var
  x,y:integer;
  aMetaData:TMetaData;
  FN: RawUTF8;
begin

  fRootFolder := EnsureDirectoryExists(ExpandFileName(aRootFolder),true);
  //fDataFolder := EnsureDirectoryExists(fRootFolder+'data'+PathDelim,true);
  fAppFolder := EnsureDirectoryExists(ExpandFileName(''),true);

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
  Html200WithNoBodyReturns204:=True;

  // adapted for OpenUI5
  URIPagingParameters.Select        := '$SELECT=';
  URIPagingParameters.StartIndex    := '$SKIP=';
  URIPagingParameters.Results       := '$TOP=';
  URIPagingParameters.Sort          := '$ORDERBY=';
  URIPagingParameters.Where         := '$FILTER=';

  Server := TCustomHttpServer.Create(PORT,[Self],'+',HTTP_DEFAULT_MODE,32,secNone,STATICROOT);
  Server.AccessControlAllowOrigin := '*'; // allow cross-site AJAX queries

  TCustomHttpServer(Server).ServerRoot:=ExtractFilePath(ParamStr(0))+WEBROOT;

  if NOT DirectoryExists(TCustomHttpServer(Server).ServerRoot) then
     TCustomHttpServer(Server).ServerRoot:=ExtractFileDir(ParamStr(0));

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
      FN:='Name="'+Model.Tables[x].RecordProps.Fields.Items[y-1].Name+'" Type='+FN+' Nullable="true" sap:creatable="true" sap:updatable="true"';
      if Model.Tables[x].RecordProps.Fields.Items[y-1].SQLDBFieldType=ftBlob
         then FN:=FN+' sap:sortable="false" sap:filterable="false"'
         else FN:=FN+' sap:sortable="true" sap:filterable="true"';
      if Model.Tables[x].RecordProps.Fields.Items[y-1].FieldWidth>0 then FN:=FN+' MaxLength="'+InttoStr(Model.Tables[x].RecordProps.Fields.Items[y-1].FieldWidth)+'"';
      aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].Property_placeholder[High(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].Property_placeholder)]:=FN;

    end;

    // do the navigation properties : mORMot joined tables !!
    for y := 1 to Length(Model.Tables[x].RecordProps.JoinedFields) do
    begin

      {$ifdef METADATAV2}
      FN:=
          'Name="'+Model.Tables[x].RecordProps.JoinedFields[y-1].Name+'"'+
          ' ToRole="'+Model.Tables[x].RecordProps.JoinedFieldsTable[y].SQLTableName+'_Members"'+
          ' FromRole="'+Model.Tables[x].SQLTableName+'_'+Model.Tables[x].RecordProps.JoinedFields[y-1].Name+'"'+
          ' Relationship="mORMot.'+Model.Tables[x].SQLTableName+'_'+Model.Tables[x].RecordProps.JoinedFields[y-1].Name+'_'+Model.Tables[x].RecordProps.JoinedFieldsTable[y].SQLTableName+'_Members"';
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

  JSONBufferToXML(pointer(FN),XMLUTF8_HEADER,'',Server.MetaData);

  {$ifdef METADATAV2}
  Server.MetaData:=StringReplace(Server.MetaData,'<Edmx_placeholder>','<edmx:Edmx xmlns:edmx="http://schemas.microsoft.com/ado/2007/06/edmx" Version="1.0">',[]);
  Server.MetaData:=StringReplace(Server.MetaData,'<DataServices_placeholder>','<edmx:DataServices xmlns:m="http://schemas.microsoft.com/ado/2007/08/dataservices/metadata" m:MaxDataServiceVersion="3.0" m:DataServiceVersion="1.0">',[]);
  Server.MetaData:=StringReplace(Server.MetaData,'<Schema>','<Schema xmlns="http://schemas.microsoft.com/ado/2009/11/edm" Namespace="mORMot" xml:lang="en">',[]);
  {$else}
  Server.MetaData:=StringReplace(Server.MetaData,'<Edmx_placeholder>','<edmx:Edmx xmlns:edmx="http://docs.oasis-open.org/odata/ns/edmx" Version="4.0">',[]);
  Server.MetaData:=StringReplace(Server.MetaData,'DataServices_placeholder','edmx:DataServices',[rfReplaceAll]);
  Server.MetaData:=StringReplace(Server.MetaData,'<Schema>','<Schema xmlns="http://docs.oasis-open.org/odata/ns/edm" Namespace="mORMot">',[]);
  {$endif}


  Server.MetaData:=StringReplace(Server.MetaData,'</Edmx_placeholder>','</edmx:Edmx>',[]);

  Server.MetaData:=StringReplace(Server.MetaData,'</DataServices_placeholder>','</edmx:DataServices>',[]);


  Server.MetaData:=StringReplace(Server.MetaData,'<Property_placeholder>','<Property ',[rfReplaceAll]);
  Server.MetaData:=StringReplace(Server.MetaData,'</Property_placeholder>',' />',[rfReplaceAll]);

  Server.MetaData:=StringReplace(Server.MetaData,'<PropertyRef>','<PropertyRef ',[rfReplaceAll]);
  Server.MetaData:=StringReplace(Server.MetaData,'</PropertyRef>',' />',[rfReplaceAll]);

  Server.MetaData:=StringReplace(Server.MetaData,'<NavigationProperty>','<NavigationProperty ',[rfReplaceAll]);
  Server.MetaData:=StringReplace(Server.MetaData,'</NavigationProperty>',' />',[rfReplaceAll]);

  {$ifndef METADATAV2}
  Server.MetaData:=StringReplace(Server.MetaData,'<Annotations>','<Annotations Target="mORMot.mORMotService">',[]);
  Server.MetaData:=StringReplace(Server.MetaData,'<Annotations>','<Annotations Target="mORMot.Team">',[]);
  Server.MetaData:=StringReplace(Server.MetaData,'<Annotations>','<Annotations Target="mORMot.Member">',[]);

  Server.MetaData:=StringReplace(Server.MetaData,'<Annotation>','<Annotation ',[rfReplaceAll]);
  Server.MetaData:=StringReplace(Server.MetaData,'</Annotation>',' />',[rfReplaceAll]);
  {$endif}


  // this is a bit tricky ...
  // everytime an <EntityType> is encountered, it is replaced by <EntityType with table name>
  // works because of the sequence of creating this (see above) ... but still tricky
  for x := 0 to high(Model.Tables) do
  begin
    {$ifdef METADATAV2}
    Server.MetaData:=StringReplace(Server.MetaData,'<EntityType>','<EntityType Name="'+Model.Tables[x].SQLTableName+'"'+
           ' Namespace="mORMot" EntityType="mORMot.'+Model.Tables[x].SQLTableName+'"'+
           ' xmlns:sap="http://www.sap.com/Protocols/SAPData"'+
           ' sap:content-version="1"'+
           '>',[]);
    {$else}
    Server.MetaData:=StringReplace(Server.MetaData,'<EntityType>','<EntityType Name="'+Model.Tables[x].SQLTableName+'"'+
           ' xmlns:sap="http://www.sap.com/Protocols/SAPData">',[]);
    {$endif}
  end;

  {$ifdef METADATAV2}
  Server.MetaData:=StringReplace(Server.MetaData,'<EntityContainer>','<EntityContainer Name="mORMotService" xmlns:sap="http://www.sap.com/Protocols/SAPData" m:IsDefaultEntityContainer="true">',[]);
  {$else}
  Server.MetaData:=StringReplace(Server.MetaData,'<EntityContainer>','<EntityContainer Name="mORMotService" xmlns:sap="http://www.sap.com/Protocols/SAPData">',[]);
  {$endif}


  Server.MetaData:=StringReplace(Server.MetaData,'<EntitySet>','<EntitySet ',[rfReplaceAll]);
  Server.MetaData:=StringReplace(Server.MetaData,'</EntitySet>',' />',[rfReplaceAll]);

  Server.MetaData:=StringReplace(Server.MetaData,'&quot;','"',[rfReplaceAll]);

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
  x,y:integer;
  match:TSQLRestModelMatch;
  aCount:Int64;
  bServeMetadata, bServeCount:boolean;
begin

  result:=0;

  bServeMetadata  := false;
  bServeCount     := false;

  TSQLLog.Add.Log(sllHTTP,'Got URL request: '+Ctxt.URL);

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

    if (Ctxt.Method='GET') then
    begin

      TSQLLog.Add.Log(sllHTTP,'Inside custom GET');

      for x := 0 to high(fDBServers) do
        with Self.fDBServers[x] do
          if Ctxt.UseSSL=(Security=secSSL) then
          begin
            match := Server.Model.URIMatch(FN);
            if match=rmNoMatch then continue;
            FN:='/'+UpperCase(Server.Model.Root)+'/$METADATA';
            if (IdemPChar(pointer(Ctxt.URL),pointer(FN))) then
            begin
              bServeMetadata := true;
              break
            end;
            for y:=0 to high(Server.Model.Tables) do
            begin
              FN:='/'+UpperCase(Server.Model.Root)+'/'+UpperCase(Server.Model.Tables[y].SQLTableName)+'/$COUNT';
              if (IdemPChar(pointer(Ctxt.URL),pointer(FN))) then
              begin
                // handle direct !!
                bServeCount := true;
                aCount:=0;
                Server.OneFieldValue(Server.Model.Tables[y], 'COUNT(*)','',[],[],aCount);
                break
              end;
            end;
          end;
    end;

    if (bServeMetadata) then
    begin
      TSQLLog.Add.Log(sllHTTP,'Got metadata request URL:  '+Ctxt.URL);
      TSQLLog.Add.Log(sllHTTP,'Sending metadata to this URL');

      Ctxt.OutContent := Self.MetaData;
      // important !!!!
      // OpenUI5 needs this header for $metadata
      Ctxt.OutContentType := 'application/xml';
      Ctxt.OutCustomHeaders:='Access-Control-Allow-Origin:*'+
      #13#10'Access-Control-Allow-Methods: POST, PUT, GET, DELETE, LOCK, OPTIONS';
      //#13#10'Access-Control-Allow-Headers: origin, x-requested-with, content-type'
      result := 200;
    end;

    if (bServeCount) then
    begin
      TSQLLog.Add.Log(sllHTTP,'Got count request URL:  '+Ctxt.URL);
      TSQLLog.Add.Log(sllHTTP,'Sending count to this URL: '+InttoStr(aCount));
      Ctxt.OutContent := InttoStr(aCount);
      Ctxt.OutContentType := TEXT_CONTENT_TYPE;
      Ctxt.OutCustomHeaders:='Access-Control-Allow-Origin:*'+
      #13#10'Access-Control-Allow-Methods: POST, PUT, GET, DELETE, LOCK, OPTIONS';
      //#13#10'Access-Control-Allow-Headers: origin, x-requested-with, content-type'
      result := 200;
    end;

    if ((NOT bServeMetadata) AND (NOT bServeCount)) then
    begin
      // call the associated TSQLRestServer instance(s)
      result := inherited Request(Ctxt);

      //if ( (Ctxt.Method='GET') AND (Length(Ctxt.OutContent)>0)) then Ctxt.OutContent := '{"d":'+Ctxt.OutContent+'}';
      FN:='APPLICATION/JSON';
      if ((Ctxt.Method='GET') AND (IdemPChar(pointer(Ctxt.OutContentType),pointer(FN))) AND (Length(Ctxt.OutContent)>0)) then Ctxt.OutContent := '{"d":'+Ctxt.OutContent+'}';

      if ( (Ctxt.Method='POST') AND (result=201)) then
      begin
        // give back new ID !!
        FN:=FindIniNameValue(pointer(Ctxt.OutCustomHeaders),'LOCATION:');
        FN:='{"ID":'+Copy(FN,Pos('/',FN)+1,MaxInt)+'}';
        Ctxt.OutContent := '{"d":'+FN+'}';
      end;

      TSQLLog.Add.Log(sllHTTP,'Got normal URL:  '+Ctxt.URL);
      TSQLLog.Add.Log(sllHTTP,'Sending to this URL:  '+Ctxt.OutContent);

    end;
  end;
end;

initialization
  TTextWriter.RegisterCustomJSONSerializerFromText(
    TypeInfo(TMetaData),__TMetaData);

end.
