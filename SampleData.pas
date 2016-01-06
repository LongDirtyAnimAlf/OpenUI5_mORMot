unit SampleData;

interface

uses
  SynCommons,
  mORMot;

const
  WEBROOT='WebContent';
  STATICROOT='static';
  INDEXFILE='index.html';
  HOST='localhost';
  PORT='8080';

type

  TSQLTeam = class(TSQLRecord)
  private
    fName: RawUTF8;
  public
    class procedure InitializeTable(Server: TSQLRestServer; const FieldName: RawUTF8;
      Options: TSQLInitializeTableOptions); override;
  published
    property Name: RawUTF8 read fName write fName;
  end;


  TAddress = class(TSynPersistent)
  protected
    fStreet: RawUTF8;
    fCity: RawUTF8;
    fZip: RawUTF8;
    fCountry: RawUTF8;
  public
    procedure Clear;
  published
    property Street: RawUTF8 read fStreet write fStreet;
    property City: RawUTF8 read fCity write fCity;
    property Zip: RawUTF8 read fZip write fZip;
    property Country: RawUTF8 read fCountry write fCountry;
  end;

  TResume = class(TSynPersistent)
  protected
    fInformation: RawUTF8;
    fProjects: RawUTF8;
    fHobbies: RawUTF8;
    fNotes: RawUTF8;
  public
    procedure Clear;
  published
    property Information: RawUTF8 read fInformation write fInformation;
    property Projects: RawUTF8 read fProjects write fProjects;
    property Hobbies: RawUTF8 read fHobbies write fHobbies;
    property Notes: RawUTF8 read fNotes write fNotes;
  end;


  TContactData = TRawUTF8List;

  TSQLMember = class(TSQLRecord)
  private
    fFirstName: RawUTF8;
    fMiddleName: RawUTF8;
    fLastName: RawUTF8;
    fAddress: RawUTF8;
    fAddress2: RawUTF8;
    fNewAddress: TAddress;
    fCity: RawUTF8;
    fState: RawUTF8;
    fZip: RawUTF8;
    fCountry: RawUTF8;
    fPhone: RawUTF8;
    fDob: RawUTF8;
    fEmail: RawUTF8;
    fSkype: RawUTF8;
    fTwitter: RawUTF8;
    fThumb: RawUTF8;
    fImage: RawUTF8;
    fNewEmail: TContactData;
    fNewPhone: TContactData;
    fPictureUrl: RawUTF8;
    fResume: TResume;
    fMemberTeam:TSQLTeam;
  public
    class procedure InitializeTable(Server: TSQLRestServer; const FieldName: RawUTF8;
      Options: TSQLInitializeTableOptions); override;
    function GetFullName: RawUTF8; virtual;
    constructor Create; override;
    destructor Destroy; override;
  published
    property FirstName: RawUTF8 read fFirstName write fFirstName;
    property MiddleName: RawUTF8 read fMiddleName write fMiddleName;
    property LastName: RawUTF8 read fLastName write fLastName;
    property Address: RawUTF8 read fAddress write fAddress;
    property Address2: RawUTF8 read fAddress2 write fAddress2;
    property NewAddress: TAddress read fNewAddress write fNewAddress;
    property City: RawUTF8 read fCity write fCity;
    property State: RawUTF8 read fState write fState;
    property Zip: RawUTF8 read fZip write fZip;
    property Country: RawUTF8 read fCountry write fCountry;
    property Phone: RawUTF8 read fPhone write fPhone;
    property Dob: RawUTF8 read fDob write fDob;
    property Email: RawUTF8 read fEmail write fEmail;
    property Skype: RawUTF8 read fSkype write fSkype;
    property Twitter: RawUTF8 read fTwitter write fTwitter;
    property Thumb: RawUTF8 read fThumb write fThumb;
    property Image: RawUTF8 read fImage write fImage;
    property NewEmail: TContactData read fNewEmail write fNewEmail;
    property NewPhone: TContactData read fNewPhone write fNewPhone;
    property PictureUrl: RawUTF8 read fPictureUrl write fPictureUrl;
    property Resume: TResume read fResume write fResume;
    property MemberTeam:TSQLTeam read fMemberTeam write fMemberTeam;
  end;

function CreateSampleModel: TSQLModel;

implementation

uses
  SysUtils;

function CreateSampleModel: TSQLModel;
begin
  result := TSQLModel.Create([TSQLTeam,TSQLMember]);
end;

class procedure TSQLTeam.InitializeTable(Server: TSQLRestServer;
  const FieldName: RawUTF8; Options: TSQLInitializeTableOptions);
var
  aTeam:TSQLTeam;
begin
  inherited InitializeTable(Server,FieldName,Options);
  if FieldName='' then
  begin
    aTeam:=Self.Create;
    try
      aTeam.Name:='Men1';
      Server.Add(ateam,true);
      aTeam.ClearProperties;
      aTeam.Name:='Men2';
      Server.Add(ateam,true);
      aTeam.ClearProperties;
      aTeam.Name:='Women1';
      Server.Add(ateam,true);
      aTeam.ClearProperties;
      aTeam.Name:='Women2';
      Server.Add(ateam,true);
      aTeam.ClearProperties;
      aTeam.Name:='Boys1';
      Server.Add(ateam,true);
      aTeam.ClearProperties;
      aTeam.Name:='Girls1';
      Server.Add(ateam,true);
      aTeam.ClearProperties;
    finally
      aTeam.Free;
    end;
  end;
end;


function TSQLMember.GetFullName: RawUTF8;
begin
  result := Trim(Trim(FirstName+' '+MiddleName)+' '+LastName);
end;

class procedure TSQLMember.InitializeTable(Server: TSQLRestServer;
  const FieldName: RawUTF8; Options: TSQLInitializeTableOptions);
var
  aMember:TSQLMember;
begin
  inherited InitializeTable(Server,FieldName,Options);
  if FieldName='' then
  begin
    {
    Rec := TSQLMember.CreateAndFillPrepare(
        StringFromFile(ExtractFilePath(paramstr(0))+'aMemberRecordInit.json'));
      try
        while Rec.FillOne do
          Server.Add(Rec,true);
      finally
        Rec.Free;
      end;
    }

    aMember:=Self.Create;
    try

      aMember.FirstName:='John';
      aMember.LastName:='Doe';
      aMember.Address:='2123 ILiveHereStreet';

      aMember.NewAddress.Street:='1234 ILiveHereStreet';

      aMember.Resume.Information:='A very interesting man';
      aMember.Resume.Hobbies:='Making fun of software developers';

      aMember.City:='Atlantis';
      aMember.NewAddress.City:='Atlantis';
      aMember.Country:='Somewhere';
      aMember.NewAddress.Country:='Somewhere';
      aMember.Email:='john.doe@gmail.com';
      aMember.NewEmail.Add('john@doe.com');
      aMember.NewEmail.Add('johnny@doe.com');
      aMember.NewEmail.Add('jd@doe.com');
      aMember.PictureUrl:='img/john.jpg';
      aMember.MemberTeam:=TSQLTeam(1);
      Server.Add(aMember,true);

      aMember.NewAddress.Clear;
      aMember.Resume.Clear;
      aMember.ClearProperties;
      aMember.FirstName:='Arnaud';
      aMember.LastName:='Bouchez';
      aMember.Email:='webcontact01@synopse.info';
      aMember.PictureUrl:='img/arnaud.jpg';
      aMember.MemberTeam:=TSQLTeam(1);
      Server.Add(aMember,true);

      aMember.FirstName:='Don';
      aMember.LastName:='Alfredo';
      aMember.Phone:='0612345678';
      aMember.Email:='longdirtyanimalf@gmail.com';
      aMember.PictureUrl:='img/don.jpg';
      aMember.MemberTeam:=TSQLTeam(2);
      Server.Add(aMember,true);

    finally
      aMember.Free;
    end;
  end;
end;

procedure TAddress.Clear;
begin
  fStreet:='';
  fCity:='';
  fZip:='';
  fCountry:='';
end;

procedure TResume.Clear;
begin
  fInformation:='';
  fProjects:='';
  fHobbies:='';
  fNotes:='';
end;


constructor TSQLMember.Create;
begin
  inherited Create;
  fNewEmail:=TContactData.Create;
  fNewEmail.CaseSensitive:=False;
  fNewPhone:=TContactData.Create;
  fNewPhone.CaseSensitive:=False;
  fNewAddress:=TAddress.Create;
  fResume:=TResume.Create;
end;

destructor TSQLMember.Destroy;
begin
  fResume.Free;
  fNewAddress.Free;
  fNewPhone.Free;
  fNewEmail.Free;
  inherited Destroy;
end;

initialization
  {$ifndef ISDELPHI2010}
  {$ifndef HASINTERFACERTTI}
  TTextWriter.RegisterCustomJSONSerializerFromTextSimpleType(TypeInfo(TAddress));
  TTextWriter.RegisterCustomJSONSerializerFromTextSimpleType(TypeInfo(TResume));
  {$endif}
  {$endif}
end.
