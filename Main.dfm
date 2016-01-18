object Form1: TForm1
  Left = 399
  Top = 247
  ActiveControl = Button1
  Caption = ' 04 - HTTP Server'
  ClientHeight = 231
  ClientWidth = 432
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = True
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnShow = FormShow
  DesignSize = (
    432
    231)
  PixelsPerInch = 96
  TextHeight = 16
  object Label1: TLabel
    Left = 8
    Top = 8
    Width = 297
    Height = 33
    Alignment = taCenter
    AutoSize = False
    Color = clBtnFace
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clTeal
    Font.Height = -16
    Font.Name = 'Tahoma'
    Font.Style = [fsBold]
    ParentColor = False
    ParentFont = False
  end
  object Label2: TLabel
    Left = 56
    Top = 56
    Width = 187
    Height = 48
    Alignment = taCenter
    Caption = 
      'HTTP Server is running on 8080.'#13#10'Also serving /WebContent'#13#10'at lo' +
      'calhost:8080/static'
    Color = clBtnFace
    ParentColor = False
    WordWrap = True
  end
  object Button1: TButton
    Left = 344
    Top = 72
    Width = 80
    Height = 32
    Caption = 'Quit'
    TabOrder = 0
    OnClick = Button1Click
  end
  object btnOpen: TButton
    Left = 344
    Top = 40
    Width = 80
    Height = 29
    Caption = 'Open site'
    TabOrder = 1
    OnClick = btnOpenClick
  end
  object Memo1: TMemo
    Left = 8
    Top = 112
    Width = 416
    Height = 112
    Anchors = [akLeft, akTop, akRight, akBottom]
    Lines.Strings = (
      'Memo1')
    ScrollBars = ssVertical
    TabOrder = 2
  end
  object btnRoot: TButton
    Left = 344
    Top = 8
    Width = 80
    Height = 29
    Caption = 'Select root'
    TabOrder = 3
    OnClick = btnRootClick
  end
  object OpenDialog1: TOpenDialog
    Filter = 'html|*.html|htm|*.htm|all|*.*'
    Left = 274
    Top = 62
  end
end
