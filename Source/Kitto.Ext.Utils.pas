unit Kitto.Ext.Utils;

interface

uses
  Ext, ExtPascal, ExtPascalUtils, ExtMenu, ExtTree,
  EF.ObserverIntf, EF.Tree,
  Kitto.Ext.Controller, Kitto.Metadata.Views;

type
  TKExtTreeTreeNode = class(TExtTreeTreeNode)
  private
    FView: TKView;
    procedure SetView(const AValue: TKView);
  public
    property View: TKView read FView write SetView;
    destructor Destroy; override;
  end;

  TKExtButton = class(TExtButton)
  private
    FView: TKView;
    procedure SetView(const AValue: TKView);
  public
    property View: TKView read FView write SetView;
    destructor Destroy; override;
  end;

  TKExtMenuItem = class(TExtMenuItem)
  private
    FView: TKView;
    procedure SetView(const AValue: TKView);
  public
    property View: TKView read FView write SetView;
    destructor Destroy; override;
  end;

  ///	<summary>
  ///	  Renders a tree view on a container in various ways: as a set of buttons
  ///	  with submenus, an Ext treeview control, etc.
  ///	</summary>
  TKExtTreeViewRenderer = class
  private
    FOwner: TExtObject;
    FClickHandler: TExtProcedure;
    FAddedItems: Integer;
    procedure AddButton(const ANode: TKTreeViewNode; const AContainer: TExtContainer);
    procedure AddMenuItem(const ANode: TKTreeViewNode; const AMenu: TExtMenuMenu);
    procedure AddNode(const ANode: TKTreeViewNode; const AParent: TExtTreeTreeNode);
    function GetClickFunction(const AView: TKView): TExtFunction;

    function FindView(const ANode: TKTreeViewNode): TKView;
  public
    ///	<summary>
    ///	  Attaches to the container a set of buttons, one for each top-level
    ///	  element of the specified tree view. Each button has a submenu tree
    ///	  with the child views. Returns the total number of effectively added
    ///	  items.
    ///	</summary>
    function RenderAsButtons(const ATreeView: TKTreeView;
      const AContainer: TExtContainer; const AOwner: TExtObject;
      const AClickHandler: TExtProcedure): Integer;

    ///	<summary>
    ///	  Renders a tree under ARoot with all views in the tree view. Returns
    ///	  the total number of effectively added items.
    ///	</summary>
    function RenderAsTree(const ATreeView: TKTreeView; const ARoot: TExtTreeTreeNode;
      const AOwner: TExtObject; const AClickHandler: TExtProcedure): Integer;
  end;

function DelphiDateFormatToJSDateFormat(const ADateFormat: string): string;
function DelphiTimeFormatToJSTimeFormat(const ATimeFormat: string): string;

implementation

uses
  SysUtils, StrUtils, HTTPApp,
  EF.SysUtils, EF.Classes, EF.Localization,
  Kitto.Environment, Kitto.AccessControl, Kitto.Ext.Session, Kitto.Ext.Base;

{ TKExtTreeViewRenderer }

function TKExtTreeViewRenderer.GetClickFunction(
  const AView: TKView): TExtFunction;
begin
  Assert(Assigned(FOwner));
  Assert(Assigned(FClickHandler));

  if Assigned(AView) then
  begin
    Assert(Session.ViewHost <> nil);
    Result := FOwner.Ajax(FClickHandler, ['Name', AView.PersistentName, 'AutoCollapseMenu', True]);
  end
  else
    Result := nil;
end;

function TKExtTreeViewRenderer.FindView(const ANode: TKTreeViewNode): TKView;
begin
  if ANode is TKTreeViewFolder then
    Result := nil
  else
    Result := Environment.Views.ViewByNode(ANode);
end;

procedure TKExtTreeViewRenderer.AddMenuItem(const ANode: TKTreeViewNode;
  const AMenu: TExtMenuMenu);
var
  I: Integer;
  LMenuItem: TKExtMenuItem;
  LSubMenu: TExtMenuMenu;
  LIsEnabled: Boolean;
  LView: TKView;
begin
  Assert(Assigned(ANode));
  Assert(Assigned(AMenu));

  for I := 0 to ANode.ChildCount - 1 do
  begin
    if ANode.Children[I] is TKTreeViewNode then
    begin
      LView := FindView(TKTreeViewNode(ANode.Children[I]));

      { TODO : implement AC }
      //if not Assigned(LView) or Environment.IsAccessGranted(LViewRef.View.GetResourceURI, ACM_VIEW) then
      begin
        LIsEnabled := not Assigned(LView) {or Environment.IsAccessGranted(AViewRef.View.GetResourceURI, ACM_RUN)};
        LMenuItem := TKExtMenuItem.AddTo(AMenu.Items);
        try
          Inc(FAddedItems);
          LMenuItem.View := LView;

          LMenuItem.Text := HTMLEncode(_(ANode.Children[I].AsString));
          if Assigned(LMenuItem.View) then
          begin
            LMenuItem.IconCls := Session.SetViewIconStyle(LMenuItem.View, ANode.Children[I].GetString('ImageName'));
            LMenuItem.On('click', GetClickFunction(LMenuItem.View));
            LMenuItem.Disabled := not LIsEnabled;
          end;
          if ANode.Children[I].ChildCount > 0 then
          begin
            LSubMenu := TExtMenuMenu.Create;
            try
              LMenuItem.Menu := LSubMenu;
              if ANode.Children[I] is TKTreeViewNode then
                AddMenuItem(TKTreeViewNode(ANode.Children[I]), LSubMenu);
            except
              FreeAndNil(LSubMenu);
              raise;
            end;
          end;
        except
          FreeAndNil(LMenuItem);
          raise;
        end;
      end;
    end;
  end;
end;

procedure TKExtTreeViewRenderer.AddButton(const ANode: TKTreeViewNode;
  const AContainer: TExtContainer);
var
  LButton: TKExtButton;
  LMenu: TExtMenuMenu;
  LIsEnabled: Boolean;
  LView: TKView;
begin
  Assert(Assigned(ANode));
  Assert(Assigned(AContainer));

  LView := FindView(ANode);

  { TODO : implement AC }
  //if not Assigned(LView) or Environment.IsAccessGranted(AViewRef.View.GetResourceURI, ACM_VIEW) then
  begin
    LIsEnabled := not Assigned(LView) {or Environment.IsAccessGranted(AViewRef.View.GetResourceURI, ACM_RUN)};
    LButton := TKExtButton.AddTo(AContainer.Items);
    try
      Inc(FAddedItems);
      LButton.View := LView;
      LButton.Text := HTMLEncode(_(ANode.AsString));
      if Assigned(LButton.View) then
      begin
        LButton.IconCls := Session.SetViewIconStyle(LButton.View, ANode.GetString('ImageName'));
        LButton.On('click', GetClickFunction(LButton.View));
        LButton.Disabled := not LIsEnabled;
      end;
      if ANode.ChildCount > 0 then
      begin
        LMenu := TExtMenuMenu.Create;
        try
          LButton.Menu := LMenu;
          AddMenuItem(ANode, LMenu);
        except
          FreeAndNil(LMenu);
          raise;
        end;
      end;
    except
      FreeAndNil(LButton);
      raise;
    end;
  end;
end;

procedure TKExtTreeViewRenderer.AddNode(const ANode: TKTreeViewNode; const AParent: TExtTreeTreeNode);
var
  LNode: TKExtTreeTreeNode;
  I: Integer;
  LIsEnabled: Boolean;
  LView: TKView;
begin
  Assert(Assigned(ANode));
  Assert(Assigned(AParent));

  LView := FindView(ANode);

  { TODO : implement AC }
  //if not Assigned(LView) or Environment.IsAccessGranted(LView.GetResourceURI, ACM_VIEW) then
  begin
    LIsEnabled := not Assigned(LView) {or Environment.IsAccessGranted(LView.GetResourceURI, ACM_RUN)};
    LNode := TKExtTreeTreeNode.Create;
    try
      Inc(FAddedItems);
      LNode.View := LView;
      LNode.Text := HTMLEncode(_(ANode.AsString));
      if Assigned(LNode.View) then
      begin
        LNode.IconCls := Session.SetViewIconStyle(LNode.View, ANode.GetString('ImageName'));
        LNode.On('click', GetClickFunction(LNode.View));
        LNode.Disabled := not LIsEnabled;
      end;
      if ANode.TreeViewNodeCount > 0 then
      begin
        for I := 0 to ANode.TreeViewNodeCount - 1 do
          AddNode(TKTreeViewNode(ANode.TreeViewNodes[I]), LNode);
        LNode.Expandable := True;
        LNode.Expanded := True;
        LNode.Leaf := False;
      end;
      AParent.AppendChild(LNode);
    except
      FreeAndNil(LNode);
      raise;
    end;
  end;
end;

function TKExtTreeViewRenderer.RenderAsButtons(
  const ATreeView: TKTreeView; const AContainer: TExtContainer;
  const AOwner: TExtObject;
  const AClickHandler: TExtProcedure): Integer;
var
  I: Integer;
begin
  Assert(Assigned(ATreeView));
  Assert(Assigned(AContainer));
  Assert(Assigned(AOwner));
  Assert(Assigned(AClickHandler));

  FOwner := AOwner;
  FClickHandler := AClickHandler;
  FAddedItems := 0;
  for I := 0 to ATreeView.TreeViewNodeCount - 1 do
    AddButton(ATreeView.TreeViewNodes[I], AContainer);
  Result := FAddedItems;
end;

function TKExtTreeViewRenderer.RenderAsTree(
  const ATreeView: TKTreeView; const ARoot: TExtTreeTreeNode;
  const AOwner: TExtObject;  const AClickHandler: TExtProcedure): Integer;
var
  I: Integer;
begin
  Assert(Assigned(ATreeView));
  Assert(Assigned(ARoot));
  Assert(Assigned(AOwner));
  Assert(Assigned(AClickHandler));

  FOwner := AOwner;
  FClickHandler := AClickHandler;
  FAddedItems := 0;
  for I := 0 to ATreeView.TreeViewNodeCount - 1 do
    AddNode(ATreeView.TreeViewNodes[I], ARoot);
  Result := FAddedItems;
end;

function DelphiDateFormatToJSDateFormat(const ADateFormat: string): string;
begin
  Result := ReplaceText(ADateFormat, 'yyyy', 'Y');
  Result := ReplaceText(Result, 'yy', 'y');
  Result := ReplaceText(Result, 'dd', 'd');
  Result := ReplaceText(Result, 'mm', 'm');
end;

function DelphiTimeFormatToJSTimeFormat(const ATimeFormat: string): string;
begin
  Result := ReplaceText(ATimeFormat, 'hh', 'H');
  Result := ReplaceText(Result, 'mm', 'i');
  Result := ReplaceText(Result, 'ss', 's');
end;

{ TKExtTreeTreeNode }

destructor TKExtTreeTreeNode.Destroy;
begin
  if Assigned(FView) and not FView.IsPersistent then
    FreeAndNil(FView);
  inherited;
end;

procedure TKExtTreeTreeNode.SetView(const AValue: TKView);
begin
  FView := AValue;
  if Assigned(FView) then
  begin
    Expandable := False;
    Expanded := False;
    Leaf := True;
  end;
end;

{ TKExtButton }

destructor TKExtButton.Destroy;
begin
  if Assigned(FView) and not FView.IsPersistent then
    FreeAndNil(FView);
  inherited;
end;

procedure TKExtButton.SetView(const AValue: TKView);
begin
  FView := AValue;
end;

{ TKExtMenuItem }

destructor TKExtMenuItem.Destroy;
begin
  if Assigned(FView) and not FView.IsPersistent then
    FreeAndNil(FView);
  inherited;
end;

procedure TKExtMenuItem.SetView(const AValue: TKView);
begin
  FView := AValue;
end;

end.
