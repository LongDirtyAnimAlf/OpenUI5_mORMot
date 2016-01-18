program SAPUI5Server;

{$I Synopse.inc}

uses
  Forms,
  Main,
  SampleData;

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
