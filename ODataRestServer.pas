unit ODataRestServer;

interface

{$I Synopse.inc}

{$define METADATAV2}

{.$define MORMOTPATCHED}

uses
  SysUtils,
  Classes,
  SynCommons,
  mORMot,
  mORMotHttpServer,
  SynCrtSock;

const
  WEBROOT='webcontent';
  STATICROOT='static';
  NAMESPACE='mORMot';

type
  TODataHttpServer = class(TSQLHttpServer)
  private
    {$ifndef METADATAV2}
    MustEncapsulate:boolean;
    {$endif}
    MetaData:RawUTF8;
    function BeforeUri(Ctxt: TSQLRestServerURIContext): boolean;
    procedure AfterUri(Ctxt: TSQLRestServerURIContext);
    function GetMetadata(aServer: TSQLRestServer):string;
    procedure ConvertODataParameters(Ctxt: TSQLRestServerURIContext);
  protected
    function Request(Ctxt: THttpServerRequest): cardinal; override;
  public
    ServerRoot:string;
    constructor Create(const aPort: AnsiString; aServer: TSQLRestServer);
  end;

implementation

uses
  {$ifndef FPC}
  System.StrUtils,
  {$endif}
  SynTable;

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
           'Association{'+
             'End_Association_placeholder array of RawUTF8 '+
           '}'+
           'EntityContainer{'+
             'EntitySet array of RawUTF8 '+
             'AssociationSet{'+
               'End_AssociationSet_placeholder array of RawUTF8 '+
             '}'+
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
          Association: record
            End_Association_placeholder: array of RawUTF8;
          end;
          EntityContainer: record
            EntitySet: array of RawUTF8;
            AssociationSet: record
              End_AssociationSet_placeholder: array of RawUTF8;
            end;
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

{ TODataHttpServer }

function TODataHttpServer.Request(Ctxt: THttpServerRequest): cardinal;
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
      //   result := HTML_NOTFOUND;
      //  exit;
      //end;

      while (FN<>'') and (FN[1]=PathDelim) do delete(FN,1,1);

      x:=Pos('?',FN);
      if x>0 then delete(FN,x,maxInt);

      while (FN<>'') and (FN[length(FN)]=PathDelim) do delete(FN,length(FN),1);

      FileName := IncludeTrailingPathDelimiter(ServerRoot)+UTF8ToString(FN);

      if DirectoryExists(FileName) then result := STATUS_FORBIDDEN else
      begin
        Ctxt.OutContent := StringToUTF8(FileName);
        Ctxt.OutContentType := HTTP_RESP_STATICFILE;
        Ctxt.OutCustomHeaders := GetMimeContentTypeHeader('',FileName);
        //#13#10'Access-Control-Allow-Origin:*'+
        //#13#10'Access-Control-Allow-Methods: POST, PUT, GET, DELETE, LOCK, OPTIONS';
        //#13#10'Access-Control-Allow-Headers: origin, x-requested-with, content-type'
        result := STATUS_SUCCESS;
      end;
    end;
  end
  else
  begin

    // serve all other contents
    TSQLLog.Add.Log(sllHTTP,'Performing inherited with URL: '+Ctxt.URL);


    result := inherited Request(Ctxt);

    {$ifdef MORMOTPATCHED}
    Ctxt.OutContent:=StringReplaceAll(Ctxt.OutContent,'REPLACEWITHROOTURI','http://'+Self.PublicAddress+':'+Self.PublicPort);
    Ctxt.OutContent:=StringReplaceAll(Ctxt.OutContent,'REPLACEWITHROOTURI','http://localhost:'+Self.PublicPort);
    {$endif}

    TSQLLog.Add.Log(sllHTTP,'Performing inherited done with URL: '+Ctxt.URL);
    TSQLLog.Add.Log(sllHTTP,'Sending result: '+Ctxt.OutContent);
  end;
end;

constructor TODataHttpServer.Create(const aPort: AnsiString; aServer: TSQLRestServer);
begin
  //inherited Create(aPort,aServer);
  inherited Create(aPort,aServer,'+',HTTP_DEFAULT_MODE,32,secNone,STATICROOT);

  aServer.Options:=[rsoGetAsJsonNotAsString,rsoHttp200WithNoBodyReturns204,rsoAddUpdateReturnsContent,rsoComputeFieldsBeforeWriteOnServerSide,rsoGetID_str];

  //$select gets rewritten already ... so URIPagingParameters.Select not needed anymore
  //aServer.URIPagingParameters.Select                := '$SELECT=';

  aServer.URIPagingParameters.StartIndex            := '$SKIP=';

  aServer.URIPagingParameters.Results               := '$TOP=';

  //$sort gets rewritten already ... so URIPagingParameters.Sort not needed anymore
  //aServer.URIPagingParameters.Sort                  := '$ORDERBY=';

  //$filter gets rewritten already ... so URIPagingParameters.Where not needed anymore
  //aServer.URIPagingParameters.Where                 := '$FILTER=';

  AccessControlAllowOrigin := '*'; // allow cross-site AJAX queries

  ServerRoot:=ExtractFilePath(ParamStr(0))+WEBROOT;

  if NOT DirectoryExists(ServerRoot) then
     ServerRoot:=ExtractFileDir(ParamStr(0));

  aServer.OnBeforeURI:=BeforeUri;
  aServer.OnAfterURI:=AfterUri;

  // make metadata
  MetaData:=GetMetadata(aServer);
end;

function TODataHttpServer.BeforeUri(Ctxt: TSQLRestServerURIContext): boolean;
var
  pParameters:PUTF8Char;
  Count,Top,Where,FN: RawUTF8;
  bUriHandled:boolean;
  {$ifdef METADATAV2}
  x:integer;
  aCount:Int64;
  {$endif}
begin
  // Here, we get the real (ORM) requests !!
  // Process them, if needed.

  if (Length(Ctxt.Server.URIPagingParameters.SendTotalRowsCountFmt)>0) then Ctxt.Server.URIPagingParameters.SendTotalRowsCountFmt := '';

  bUriHandled:=false;

  if Ctxt.ClientKind=ckAJAX then
  begin
    {$ifndef METADATAV2}
    MustEncapsulate:=true;
    {$endif}

    TSQLLog.Add.Log(sllHTTP,'Got new URI:  '+Ctxt.URI);
    TSQLLog.Add.Log(sllHTTP,'Got new URL:  '+Ctxt.Call^.Url);
    TSQLLog.Add.Log(sllHTTP,'Got new Method:  '+GetEnumNameTrimed(TypeInfo(TSQLURIMethod), Ctxt.Method));
    TSQLLog.Add.Log(sllHTTP,'Got new Body:  '+Ctxt.Call^.InBody);


    if ((NOT bUriHandled) AND (Ctxt.Method=mGET)) then
    begin
      FN:=UpperCase(Ctxt.Server.Model.Root)+'/$METADATA';
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
        Ctxt.Call^.OutStatus := STATUS_SUCCESS;
        bUriHandled:=true;
      end;
    end;

    {$ifdef METADATAV2}
    if ((NOT bUriHandled) AND (Ctxt.Method=mGET)) then
    begin
      for x:=0 to high(Ctxt.Server.Model.Tables) do
      begin
        FN:=UpperCase(Ctxt.Server.Model.Root)+'/'+UpperCase(Ctxt.Server.Model.Tables[x].SQLTableName)+'/$COUNT';
        if (IdemPChar(pointer(Ctxt.Call^.Url),pointer(FN))) then
        begin
          aCount:=0;
          Ctxt.Server.OneFieldValue(Ctxt.Server.Model.Tables[x], 'COUNT(*)','',[],[],aCount);
          TSQLLog.Add.Log(sllHTTP,'Got V2 count request URL:  '+Ctxt.Call^.Url);
          TSQLLog.Add.Log(sllHTTP,'Sending record count to this URL');
          Ctxt.Call^.OutBody:=InttoStr(aCount);
          Ctxt.Call^.OutHead:=HEADER_CONTENT_TYPE+TEXT_CONTENT_TYPE+
          #13#10'Access-Control-Allow-Origin:*'+
          #13#10'Access-Control-Allow-Methods: POST, PUT, GET, DELETE, LOCK, OPTIONS';
          //#13#10'Access-Control-Allow-Headers: origin, x-requested-with, content-type'
          Ctxt.Call^.OutStatus := STATUS_SUCCESS;
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
        Where:='';

        if pParameters^<>#0 then
        repeat
          {$ifdef METADATAV2}
          UrlDecodeValue(pParameters,'$INLINECOUNT=',Count);
          {$else}
          UrlDecodeValue(pParameters,'$COUNT=',Count);
          {$endif}
          // intercept the Where parameters for later user-processsing !!
          UrlDecodeValue(pParameters,'$FILTER=',Where);
          UrlDecodeValue(pParameters,Ctxt.Server.URIPagingParameters.Results,Top,@pParameters);
        until pParameters=nil;

        if (Length(Count)>0) AND {$ifdef METADATAV2} (IdemPChar(pointer(Count),'ALLPAGES')) {$else} ((IdemPChar(pointer(Count),'TRUE'))) {$endif} then
        begin
          {$ifdef METADATAV2}
          Ctxt.Server.URIPagingParameters.SendTotalRowsCountFmt :=',"__count":"%"';
          //mORMot feature request ... not yet available
          //aServer.URIPagingParameters.EncapsulateResultFmt := '"results"';
          {$else}
          MustEncapsulate:=False;
          Ctxt.Server.URIPagingParameters.SendTotalRowsCountFmt :=',"@odata.count":%';
          //mORMot feature request ... not yet available
          //aServer.URIPagingParameters.EncapsulateResultFmt := '"value"';
          {$endif}
          if Top='' then
          begin
            // Must add URIPagingParameters.Results (in form of $top): without it, the mORMot does not return results
            // See this line in mORMot.pas:
            // if (SQLResults<>0) and not ContainsUTF8(pointer(SQLWhere),'LIMIT ') then begin
            // inside of procedure TSQLRestServerURIContext.ExecuteORMGet;
            // Kind of a hack ... ;-)
            Ctxt.Call^.Url:=Ctxt.Call^.Url+'&$top='+InttoStr(MaxInt);
          end;
        end;

        // process OData commands and convert into mORMot commands
        ConvertODataParameters(Ctxt);

      end;
    end;

    if (NOT bUriHandled) then
    begin
      // here, we should add extra filters to prevent users from seeing to much !!
      // important, but still todo

      // the session number
      //Session: cardinal;

      /// the corresponding TAuthSession.User.ID value
      //Ctxt.SessionUser:=;

      //the corresponding TAuthSession.User.GroupRights.ID
      //Ctxt.SessionGroup


      // finally, adapt some embedded variables to point to the right position.
      Ctxt.ParametersPos := PosEx(RawUTF8('?'),Ctxt.Call^.url,1);
      if Ctxt.ParametersPos>0 then
         Ctxt.Parameters := @Ctxt.Call^.url[Ctxt.ParametersPos+1];
    end;
  end;

  TSQLLog.Add.Log(sllHTTP,'Got new URL:  '+Ctxt.Call^.Url);

  //execute command if necessary
  result:=(NOT bUriHandled);
end;

procedure TODataHttpServer.AfterUri(Ctxt: TSQLRestServerURIContext);
var
  FN:RawUTF8;
begin
  TSQLLog.Add.Log(sllHTTP,'Set new URI:  '+Ctxt.URI);
  TSQLLog.Add.Log(sllHTTP,'Set new URL:  '+Ctxt.Call^.Url);
  TSQLLog.Add.Log(sllHTTP,'Set new Method:  '+GetEnumNameTrimed(TypeInfo(TSQLURIMethod), Ctxt.Method));
  TSQLLog.Add.Log(sllHTTP,'Set new Body:  '+Ctxt.Call^.InBody);

  if Ctxt.ClientKind=ckAJAX then
  begin
    if (Length(Ctxt.Server.URIPagingParameters.SendTotalRowsCountFmt)>0) then
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

    {$ifdef MORMOTPATCHED}
    Ctxt.Call^.OutBody:=StringReplaceAll(Ctxt.Call^.OutBody,'REPLACEWITHROOTURI','REPLACEWITHROOTURI/'+Self.Model.Root);
    Ctxt.Call^.OutBody:=StringReplaceAll(Ctxt.Call^.OutBody,'REPLACEWITHNAMESPACE','mORMot');
    {$endif}

    {$else}
    if MustEncapsulate then Ctxt.Call^.OutBody := '{"value":'+Ctxt.Call^.OutBody+'}';
    {$endif}
  end;
end;

function TODataHttpServer.GetMetadata(aServer: TSQLRestServer):string;
var
  aMetaData:TMetaData;
  x,y:integer;
  FN:RawUTF8;
  RawMetaData:RawUTF8;
  aSQLModel:TSQLModel;
begin

  aSQLModel:=aServer.Model;

  SetLength(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType,length(aSQLModel.Tables));
  SetLength(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityContainer.EntitySet,length(aSQLModel.Tables));

  for x := 0 to high(aSQLModel.Tables) do
  begin
    // setting of key .... for mORMot always ID
    aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].Key.PropertyRef:='Name="ID"';

    //SetLength(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].Property_placeholder,aSQLModel.Tables[x].RecordProps.Fields.Count+1);
    //aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].Property_placeholder[0]:='Name="ID" Nullable="false" Type='+INT64TYPE;

    // setting of fields
    SetLength(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].Property_placeholder,1);
    aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].Property_placeholder[0]:='Name="ID" Nullable="false" Type='+INT64TYPE;

    if (rsoGetID_str in aServer.Options) then
    begin
      SetLength(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].Property_placeholder,Length(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].Property_placeholder)+1);
      aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].Property_placeholder[High(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].Property_placeholder)]:='Name="ID_str" Nullable="false" Type="Edm.String"';
    end;

    for y := 1 to (aSQLModel.Tables[x].RecordProps.Fields.Count) do
    begin

      if aSQLModel.Tables[x].RecordProps.Fields.Items[y-1].SQLFieldType=sftTID then continue;
      if aSQLModel.Tables[x].RecordProps.Fields.Items[y-1].SQLFieldType=sftID then continue;

      // coarse setting of type
      case aSQLModel.Tables[x].RecordProps.Fields.Items[y-1].SQLDBFieldType of
        ftNull:     FN := '"Null"';
        ftInt64:    FN := INT64TYPE;
        {$ifndef METADATAV2}
        ftDouble:   FN := '"Edm.Double"';
        ftCurrency: FN := '"Edm.Double"';
        //ftCurrency: FN := '"Edm.Decimal"';
        {$endif}
        ftDate:     FN := '"Edm.DateTime"';
        ftUTF8:     FN := '"Edm.String"';
        ftBlob:     FN := '"Edm.Binary"';
      else
        FN := '"Edm.String"';
      end;

      // finetuning of type
      case aSQLModel.Tables[x].RecordProps.Fields.Items[y-1].SQLFieldType of
        sftBoolean:   FN := '"Edm.Boolean"';
        sftInteger:   FN := '"Edm.Int32"';
        sftEnumerate: FN := '"Edm.Int16"';
        sftSet:       FN := '"Edm.Int16"';
        // experimental !!
        sftObject:    FN := '"Collection(Edm.String)"';
      end;

      SetLength(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].Property_placeholder,Length(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].Property_placeholder)+1);
      FN:='Name="'+aSQLModel.Tables[x].RecordProps.Fields.Items[y-1].Name+'" Type='+FN+' Nullable="true" sap:updatable="true"';
      if (aSQLModel.Tables[x].RecordProps.Fields.Items[y-1].SQLDBFieldType=ftBlob) OR (aSQLModel.Tables[x].RecordProps.Fields.Items[y-1].Name='PictureUrl')
         then FN:=FN+' sap:sortable="false" sap:filterable="false" sap:creatable="false"'
         else FN:=FN+' sap:sortable="true" sap:filterable="true" sap:creatable="true"';
      if aSQLModel.Tables[x].RecordProps.Fields.Items[y-1].FieldWidth>0 then FN:=FN+' MaxLength="'+InttoStr(aSQLModel.Tables[x].RecordProps.Fields.Items[y-1].FieldWidth)+'"';
      aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].Property_placeholder[High(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].Property_placeholder)]:=FN;

    end;

    // do the navigation properties : mORMot joined tables !!
    for y := 1 to Length(aSQLModel.Tables[x].RecordProps.JoinedFields) do
    begin

      {$ifdef METADATAV2}
      FN:=
          'Name="'+aSQLModel.Tables[x].RecordProps.JoinedFields[y-1].Name+'"'+
          //' ToRole="'+aSQLModel.Tables[x].RecordProps.JoinedFieldsTable[y].SQLTableName+'"'+
          ' ToRole="'+aSQLModel.Tables[x].RecordProps.JoinedFieldsTable[y].SQLTableName+'_'+aSQLModel.Tables[x].SQLTableName+'s"'+ // fully made up !!!!!
          //' FromRole="'+aSQLModel.Tables[x].SQLTableName+'"'+
          ' FromRole="'+aSQLModel.Tables[x].SQLTableName+'_'+aSQLModel.Tables[x].RecordProps.JoinedFields[y-1].Name+'"'+
          // the stated relationship as below should be a pointer to an Association and an AssociationSet: not implemented (yet)
          ' Relationship="'+NAMESPACE+'.FK_'+aSQLModel.Tables[x].RecordProps.JoinedFieldsTable[y].SQLTableName+'_'+aSQLModel.Tables[x].SQLTableName+'"';
      {$else}
      FN:=
        'Name="'+aSQLModel.Tables[x].RecordProps.JoinedFields[y-1].Name+'"'+
        ' Type="'+NAMESPACE+'.'+aSQLModel.Tables[x].RecordProps.JoinedFieldsTable[y].SQLTableName+'"';//+
        //' Partner="Members"';
        //' Partner="'+aSQLModel.Tables[x].SQLTableName+'s"';
      {$endif}
      SetLength(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].NavigationProperty,Length(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].NavigationProperty)+1);
      aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].NavigationProperty[High(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityType[x].NavigationProperty)]:=FN;
    end;

    // setting of entityset
    if (aSQLModel.Tables[x].InheritsFrom(TSQLAuthUser)) OR (aSQLModel.Tables[x].InheritsFrom(TSQLAuthGroup))
       then FN:='sap:creatable="false" sap:updatable="true" sap:deletable="false"'
       else FN:='sap:creatable="true" sap:updatable="true" sap:deletable="true"';
    aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.EntityContainer.EntitySet[x]:=
      'Name="'+aSQLModel.Tables[x].SQLTableName+'"'+
      ' EntityType="'+NAMESPACE+'.'+aSQLModel.Tables[x].SQLTableName+'"'+
      ' sap:pageable="true" sap:content-version="1" '+FN;
  end;

  {$ifndef METADATAV2}
  SetLength(aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.Annotations,3);
  aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.Annotations[0].Annotation:='Term="Org.OData.Display.V1.Description" String="This is a sample mORMot OData service"';
  aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.Annotations[1].Annotation:='Term="Org.OData.Display.V1.Description" String="All teams"';
  aMetaData.Edmx_placeholder.DataServices_placeholder.Schema.Annotations[2].Annotation:='Term="Org.OData.Display.V1.Description" String="All members"';
  {$endif}

  FN := RecordSaveJSON(aMetaData,TypeInfo(TMetaData));

  JSONBufferToXML(PUTF8Char(FN),XMLUTF8_HEADER,'',RawMetaData);

  {$ifdef METADATAV2}
  RawMetaData:=StringReplace(RawMetaData,'<Edmx_placeholder>','<edmx:Edmx xmlns:edmx="http://schemas.microsoft.com/ado/2007/06/edmx" Version="1.0">',[]);
  RawMetaData:=StringReplace(RawMetaData,'<DataServices_placeholder>','<edmx:DataServices xmlns:m="http://schemas.microsoft.com/ado/2007/08/dataservices/metadata" m:MaxDataServiceVersion="2.0" m:DataServiceVersion="2.0">',[]);
  RawMetaData:=StringReplace(RawMetaData,'<Schema>','<Schema xmlns="http://schemas.microsoft.com/ado/2009/11/edm" Namespace="'+NAMESPACE+'" xml:lang="en">',[]);
  {$else}
  RawMetaData:=StringReplace(RawMetaData,'<Edmx_placeholder>','<edmx:Edmx xmlns:edmx="http://docs.oasis-open.org/odata/ns/edmx" Version="4.0">',[]);
  RawMetaData:=StringReplaceAll(RawMetaData,'DataServices_placeholder','edmx:DataServices');
  RawMetaData:=StringReplace(RawMetaData,'<Schema>','<Schema xmlns="http://docs.oasis-open.org/odata/ns/edm" Namespace="'+NAMESPACE+'">',[]);
  {$endif}


  RawMetaData:=StringReplace(RawMetaData,'</Edmx_placeholder>','</edmx:Edmx>',[]);

  RawMetaData:=StringReplace(RawMetaData,'</DataServices_placeholder>','</edmx:DataServices>',[]);


  RawMetaData:=StringReplaceAll(RawMetaData,'<Property_placeholder>','<Property ');
  RawMetaData:=StringReplaceAll(RawMetaData,'</Property_placeholder>',' />');

  RawMetaData:=StringReplaceAll(RawMetaData,'<PropertyRef>','<PropertyRef ');
  RawMetaData:=StringReplaceAll(RawMetaData,'</PropertyRef>',' />');

  RawMetaData:=StringReplaceAll(RawMetaData,'<NavigationProperty>','<NavigationProperty ');
  RawMetaData:=StringReplaceAll(RawMetaData,'</NavigationProperty>',' />');

  {$ifndef METADATAV2}
  RawMetaData:=StringReplace(RawMetaData,'<Annotations>','<Annotations Target="'+NAMESPACE+'.mORMotService">',[]);
  RawMetaData:=StringReplace(RawMetaData,'<Annotations>','<Annotations Target="'+NAMESPACE+'.Team">',[]);
  RawMetaData:=StringReplace(RawMetaData,'<Annotations>','<Annotations Target="'+NAMESPACE+'.Member">',[]);

  RawMetaData:=StringReplaceAll(RawMetaData,'<Annotation>','<Annotation ');
  RawMetaData:=StringReplaceAll(RawMetaData,'</Annotation>',' />');
  {$endif}


  // this is a bit tricky ...
  // everytime an <EntityType> is encountered, it is replaced by <EntityType with table name>
  // works because of the sequence of creating this (see above) ... but still tricky
  for x := 0 to high(aSQLModel.Tables) do
  begin
    {$ifdef METADATAV2}
    RawMetaData:=StringReplace(RawMetaData,'<EntityType>','<EntityType Name="'+aSQLModel.Tables[x].SQLTableName+'"'+
           ' Namespace="'+NAMESPACE+'" EntityType="'+NAMESPACE+'.'+aSQLModel.Tables[x].SQLTableName+'"'+
           ' xmlns:sap="http://www.sap.com/Protocols/SAPData"'+
           ' sap:content-version="1"'+
           '>',[]);
    {$else}
    RawMetaData:=StringReplace(RawMetaData,'<EntityType>','<EntityType Name="'+aSQLModel.Tables[x].SQLTableName+'"'+
           ' xmlns:sap="http://www.sap.com/Protocols/SAPData">',[]);
    {$endif}
  end;

  {$ifdef METADATAV2}
  RawMetaData:=StringReplace(RawMetaData,'<EntityContainer>','<EntityContainer Name="mORMotService" xmlns:sap="http://www.sap.com/Protocols/SAPData" m:IsDefaultEntityContainer="true">',[]);
  {$else}
  RawMetaData:=StringReplace(RawMetaData,'<EntityContainer>','<EntityContainer Name="mORMotService" xmlns:sap="http://www.sap.com/Protocols/SAPData">',[]);
  {$endif}

  RawMetaData:=StringReplaceAll(RawMetaData,'<EntitySet>','<EntitySet ');
  RawMetaData:=StringReplaceAll(RawMetaData,'</EntitySet>',' />');

  RawMetaData:=StringReplaceAll(RawMetaData,'&quot;','"');

  result:=RawMetaData;
end;

procedure TODataHttpServer.ConvertODataParameters(Ctxt: TSQLRestServerURIContext);
var
  aFilter,aNewField,aNewFieldValue:string;
  x,y:integer;
begin
  // quote true
  if Pos(':true',Ctxt.Call^.Url)>0 then
  Ctxt.Call^.Url:=StringReplaceAll(Ctxt.Call^.Url,':true',':"true"');

  // quote false
  if Pos(':false',Ctxt.Call^.Url)>0 then
  Ctxt.Call^.Url:=StringReplaceAll(Ctxt.Call^.Url,':false',':"false"');

  // process OData sort command
  if Pos('$orderby',Ctxt.Call^.Url)>0 then
  begin
    Ctxt.Call^.Url:=StringReplaceAll(Ctxt.Call^.Url,'%20asc','&dir=asc');
    //Ctxt.Call^.Url:=StringReplaceAll(Ctxt.Call^.Url,' asc','&dir=asc');
    Ctxt.Call^.Url:=StringReplaceAll(Ctxt.Call^.Url,'%20desc','&dir=desc');
    //Ctxt.Call^.Url:=StringReplaceAll(Ctxt.Call^.Url,' desc','&dir=desc');
    Ctxt.Call^.Url:=StringReplaceAll(Ctxt.Call^.Url,'$orderby','sort');
  end;

  // remove empty filter
  if Pos('$filter=()',Ctxt.Call^.Url)>0 then
  begin
    Ctxt.Call^.Url:=StringReplaceAll(Ctxt.Call^.Url,'$filter=()','');
    // remove stale double placeholder
    Ctxt.Call^.Url:=StringReplaceAll(Ctxt.Call^.Url,'&&','&');
    // replace stale placeholders at end
    if RightStr(Ctxt.Call^.Url,1)='&' then Delete(Ctxt.Call^.Url,Length(Ctxt.Call^.Url),1);
    if RightStr(Ctxt.Call^.Url,1)='?' then Delete(Ctxt.Call^.Url,Length(Ctxt.Call^.Url),1);
  end;

  // process filter command
  if Pos('$filter',Ctxt.Call^.Url)>0 then
  begin
    Ctxt.Call^.Url:=StringReplaceAll(Ctxt.Call^.Url,'%20eq%20','%20=%20');
    //Ctxt.Call^.Url:=StringReplaceAll(Ctxt.Call^.Url,' eq ',' = ');
    Ctxt.Call^.Url:=StringReplaceAll(Ctxt.Call^.Url,'%20lt%20','%20<%20');
    //Ctxt.Call^.Url:=StringReplaceAll(Ctxt.Call^.Url,' lt ',' < ');
    Ctxt.Call^.Url:=StringReplaceAll(Ctxt.Call^.Url,'%20le%20','%20<=%20');
    //Ctxt.Call^.Url:=StringReplaceAll(Ctxt.Call^.Url,' le ',' <= ');
    Ctxt.Call^.Url:=StringReplaceAll(Ctxt.Call^.Url,'%20gt%20','%20>%20');
    //Ctxt.Call^.Url:=StringReplaceAll(Ctxt.Call^.Url,' gt ',' > ');
    Ctxt.Call^.Url:=StringReplaceAll(Ctxt.Call^.Url,'%20ge%20','%20>=%20');
    //Ctxt.Call^.Url:=StringReplaceAll(Ctxt.Call^.Url,' ge ',' >= ');
    Ctxt.Call^.Url:=StringReplaceAll(Ctxt.Call^.Url,'%20ne%20','%20<>%20');
    //Ctxt.Call^.Url:=StringReplaceAll(Ctxt.Call^.Url,' ne ',' <> ');


    while (true) do
    begin
      // find filters in form of : substringof(value,field)
      // and convert into something our mORMot understands
      x:=Pos('substringof(',Ctxt.Call^.Url);
      if x=0 then break else
      begin
        aFilter := Copy(Ctxt.Call^.Url,x+length('substringof('),MaxInt);
        aFilter := LeftStr(aFilter,Pos(')',aFilter)-1);
        // aFilter = 'value,field'

        y:=Pos(',',aFilter);

        aNewField := Copy(aFilter,y+1,MaxInt);
        aNewFieldValue := Copy(aFilter,1,y-1);
        // lazy decoding of field ...
        aNewFieldValue := UrlDecode(Pointer(aNewFieldValue));
        // remove quotes ...
        aNewFieldValue := StringReplaceAll(aNewFieldValue,'''','');
        //construct new Url
        Ctxt.Call^.Url:=StringReplace(Ctxt.Call^.Url,'substringof('+aFilter+')',aNewField+'%20LIKE%20%27%25'+aNewFieldValue+'%25%27',[]);
      end;
    end;

    while (true) do
    begin
      // find filters in form of : startswith(value,field)
      // and convert into something our mORMot understands
      x:=Pos('startswith(',Ctxt.Call^.Url);
      if x=0 then break else
      begin
        aFilter := Copy(Ctxt.Call^.Url,x+length('startswith('),MaxInt);
        aFilter := LeftStr(aFilter,Pos(')',aFilter)-1);
        // aFilter = 'field,value'

        y:=Pos(',',aFilter);

        aNewField := Copy(aFilter,1,y-1);
        aNewFieldValue := Copy(aFilter,y+1,MaxInt);
        // lazy decoding of field ...
        aNewFieldValue := UrlDecode(Pointer(aNewFieldValue));
        // remove quotes ...
        aNewFieldValue := StringReplaceAll(aNewFieldValue,'''','');
        //construct new Url
        Ctxt.Call^.Url:=StringReplace(Ctxt.Call^.Url,'startswith('+aFilter+')',aNewField+'%20LIKE%20%27'+aNewFieldValue+'%25%27',[]);
      end;
    end;

    while (true) do
    begin
      // find filters in form of : endswith(value,field)
      // and convert into something our mORMot understands
      x:=Pos('endswith(',Ctxt.Call^.Url);
      if x=0 then break else
      begin
        aFilter := Copy(Ctxt.Call^.Url,x+length('endswith('),MaxInt);
        aFilter := LeftStr(aFilter,Pos(')',aFilter)-1);
        // aFilter = 'field,value'

        y:=Pos(',',aFilter);

        aNewField := Copy(aFilter,1,y-1);
        aNewFieldValue := Copy(aFilter,y+1,MaxInt);
        // lazy decoding of field ...
        aNewFieldValue := UrlDecode(Pointer(aNewFieldValue));
        // remove quotes ...
        aNewFieldValue := StringReplaceAll(aNewFieldValue,'''','');
        //construct new Url
        Ctxt.Call^.Url:=StringReplace(Ctxt.Call^.Url,'endswith('+aFilter+')',aNewField+'%20LIKE%20%27%25'+aNewFieldValue+'%27',[]);
      end;
    end;

    while (true) do
    begin
      // find filters in form of : toupper(field)
      // and convert into something our mORMot understands
      x:=Pos('toupper(',Ctxt.Call^.Url);
      if x=0 then break else
      begin
        aFilter := Copy(Ctxt.Call^.Url,x+length('toupper('),MaxInt);
        aFilter := LeftStr(aFilter,Pos(')',aFilter)-1);
        aNewField := aFilter;
        //construct new Url
        Ctxt.Call^.Url:=StringReplace(Ctxt.Call^.Url,'toupper('+aFilter+')','UPPER('+aNewField+')',[]);
      end;
    end;

    while (true) do
    begin
      // find filters in form of : tolower(field)
      // and convert into something our mORMot understands
      x:=Pos('tolower(',Ctxt.Call^.Url);
      if x=0 then break else
      begin
        aFilter := Copy(Ctxt.Call^.Url,x+length('tolower('),MaxInt);
        aFilter := LeftStr(aFilter,Pos(')',aFilter)-1);
        aNewField := aFilter;
        //construct new Url
        Ctxt.Call^.Url:=StringReplace(Ctxt.Call^.Url,'tolower('+aFilter+')','LOWER('+aNewField+')',[]);
      end;
    end;

    Ctxt.Call^.Url:=StringReplaceAll(Ctxt.Call^.Url,'$filter','where');
  end;


  // process select command
  // just a rplace !
  Ctxt.Call^.Url:=StringReplaceAll(Ctxt.Call^.Url,'$select','select');
end;


initialization
  // register complex OData metadata record for serialization
  TTextWriter.RegisterCustomJSONSerializerFromText(
    TypeInfo(TMetaData),__TMetaData);

end.
