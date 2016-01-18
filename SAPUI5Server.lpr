program SAPUI5Server;

{$I Synopse.inc}

uses
  {$ifdef FPC}
  Interfaces,
  {$endif}
  Forms,
  Main,
  SampleData;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
