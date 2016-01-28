sap.ui.define([
	'sap/ui/demo/mORMot/localService/BaseController',
	'sap/ui/demo/mORMot/model/formatter',
	'sap/ui/Device',	
	'sap/ui/core/Fragment',
	'sap/m/MessageToast',	
	'sap/ui/model/Filter',
	'sap/ui/model/FilterOperator',
	'sap/ui/model/Sorter',
	'sap/m/Dialog',
	'sap/m/Button'
], function (BaseController,
			 formatter,
			 Device,
			 Fragment,
			 MessageToast,			 
			 Filter,
			 FilterOperator,
			 Sorter,
			 Dialog,
			 Button) {
	"use strict";
	
	return BaseController.extend("sap.ui.demo.mORMot.view.Home", {
		formatter : formatter,

		onInit: function () {
			this._search();
		},
		
		onExit : function () {
			if (this._oDialog) {
				this._oDialog.destroy();
			}
			
			if (this._NewTeamDialog) {
				this._NewTeamDialog.destroy();
			}			
			
		}, 		

		handleSearch: function (oEvent) {
			if (oEvent.getParameters().refreshButtonPressed) {
				// Search field's 'refresh' button has been pressed.
				this.handleRefresh(this.getView().byId("pullToRefresh"));
			} else {
				var sQuery = oEvent.getParameter("query");
				this._search(sQuery);
			}
		},

		handleRefresh: function (oEvent) {
			var that = this;
			
			var pullToRefreshControl;
			
			if (oEvent instanceof sap.ui.base.Event) {
				pullToRefreshControl = oEvent.getSource();
			} else {
				pullToRefreshControl = oEvent;
			}
			
			// trigger search again and hide pullToRefresh when data ready
			var oMemberList = this.getView().byId("MemberList");
			var oBinding = oMemberList.getBinding("items");
			
			var fnHandler = function () {
				pullToRefreshControl.hide();
				oBinding.detachDataReceived(fnHandler);
			};
			oBinding.attachDataReceived(fnHandler);
			
			//oBinding.refresh();
			that._search();
		},

		_search: function (sQuery) {
			
			
			var oView = this.getView();
			var oMemberList = oView.byId("MemberList");
			//oMemberList.bindAggregation("items", "/Member", new sap.ui.core.ListItem({text:"{FirstName}"}));
			
			var oTeamList = oView.byId("TeamList");
			var oSortFirstNameButton = oView.byId("SortFirstNameButton");
			var oSortLastNameButton = oView.byId("SortLastNameButton");
			var oAddTeamButton = oView.byId("AddTeamButton");			
			var oAllMembersButton = oView.byId("AllMembersButton");			
			
			//var oSearchFieldValue = ( sQuery || oView.byId("searchField").getValue());
			
			var oSearchFieldValue = sQuery ? sQuery : oView.byId("searchField").getValue();

			// switch visibility of lists and buttons
			
			var bShowSearch = oSearchFieldValue.length !== 0;
			
			oMemberList.toggleStyleClass("invisible", !bShowSearch);
			oTeamList.toggleStyleClass("invisible", bShowSearch);
			oSortFirstNameButton.toggleStyleClass("invisible", !bShowSearch);
			oSortLastNameButton.toggleStyleClass("invisible", !bShowSearch);			
			oAddTeamButton.toggleStyleClass("invisible", bShowSearch);
			oAllMembersButton.toggleStyleClass("invisible", bShowSearch);			

			if (bShowSearch) {
				this._changeNoDataTextToIndicateLoading(oMemberList);
			}

			// filter Member list
			var allFilters = [];
			var oBinding = oMemberList.getBinding("items");
			if (oBinding) {
			
				// set default sorter
				if (oBinding.aSorters.length == 0) {
					this.handleMemberSortLastNameButtonPress();
				}
				if (!bShowSearch) {
					oBinding.filter();					
				} else {
					allFilters = [ 
						           new sap.ui.model.Filter("FirstName", sap.ui.model.FilterOperator.Contains, oSearchFieldValue),
						           new sap.ui.model.Filter("LastName", sap.ui.model.FilterOperator.Contains, oSearchFieldValue)
					];
				}
				oBinding.filter(new sap.ui.model.Filter(allFilters, false));				
			}
		},

		_changeNoDataTextToIndicateLoading: function (oList) {
			var sOldNoDataText = oList.getNoDataText();
			oList.setNoDataText("Loading...");
			oList.attachEventOnce("updateFinished", function () {
				oList.setNoDataText(sOldNoDataText);
			});
		},

		handleTeamListItemPress: function (oEvent) {
			var oBindContext = oEvent.getSource().getBindingContext();
			var oTeamID = oBindContext.getObject().ID;
			this._router().navTo("Team", {TeamID:  oTeamID});			
		},

		handleMemberListSelect: function (oEvent) {
			var oItem = oEvent.getParameter("listItem");
			this._showMember(oItem);
		},

		handleMemberListItemPress: function (oEvent) {
			var oItem = oEvent.getSource();
			this._showMember(oItem);
		},

		handleMemberSortFirstNameButtonPress: function (oEvent) {
			var oFirstNameSorter = new Sorter("FirstName", false, function (oContext) {
				var name = oContext.getProperty("FirstName");
				var sKey = name.charAt(0);
				var text = name.charAt(0);
				return {
					key: sKey, // group by first letter of firstname
					text: text
				};
			});
			var oView = this.getView();
			var oMemberList = oView.byId("MemberList");
			//var oItem = oEvent.getSource();
			var oBinding = oMemberList.getBinding("items");
			oBinding.sort(oFirstNameSorter);			
		},

		handleMemberSortLastNameButtonPress: function (oEvent) {
			var oLastNameSorter = new Sorter("LastName", false, function (oContext) {
				var name = oContext.getProperty("LastName");
				var sKey = name.charAt(0);
				var text = name.charAt(0);
				return {
					key: sKey, // group by first letter of lastname
					text: text
				};
			});
			var oView = this.getView();
			var oMemberList = oView.byId("MemberList");
			//var oItem = oEvent.getSource();
			var oBinding = oMemberList.getBinding("items");
			oBinding.sort(oLastNameSorter);			
		},		
		
		_showMember: function (oItem) {
			var oBindContext = oItem.getBindingContext();
			var sId = oBindContext.getProperty(oBindContext.getPath()).ID;			
			this._router().navTo("TeamMember", {MemberID: sId}, !sap.ui.Device.system.phone);
		},
		
		getTeamId: function (iID) {
			console.log("Got you !!");
			console.log(iID);			
		},
		
		onAddTeamFloat: function (oEvent) {
			var that = this;
			if (!this._NewTeamDialog) {

				var oBundle = this.getOwnerComponent().getModel("i18n").getResourceBundle();				
				
				// create new team dialog
				var oInputTeamView = sap.ui.view({
					id: "NewTeam",
					viewName: "sap.ui.demo.mORMot.view.NewTeam",
					type: "XML"
				});
				this._NewTeamDialog = new Dialog({
					title: oBundle.getText("TEAM_ADD_PAGE_TITLE"),
					stretch: "{device>/isPhone}",
					content: [
						oInputTeamView
					],
					leftButton: new Button({
						text: oBundle.getText("SAVE_BUTTON_TEXT"),
						type: "Accept",
						press: function () {
							var bInputValid = oInputTeamView.getController()._checkInput();
							if (bInputValid) {
								var oModel = that.getOwnerComponent().getModel();
								var mData = oInputTeamView.getModel("newTeam").getData();
								var mNewTeam = {
										"Name": mData.Name
								};
								oModel.create("/Team", mNewTeam, {
									success: function() {
										that._NewTeamDialog.close();
										sap.m.MessageToast.show(oBundle.getText("ADD_TEAM_SUCCESS_TEXT"));								
									},
									error: function() {
										alert(oBundle.getText("ADD_TEAM_FAILURE_TEXT"));
									}
								});
							}
						}
					}),
					rightButton: new Button({
						text: oBundle.getText("CANCEL_BUTTON_TEXT"),
						press: function () {
							that._NewTeamDialog.close();
						}
					})
				});

				this.getView().addDependent(this._NewTeamDialog);
			}

			// open new member dialog
			this._NewTeamDialog.open();
		},
		
		onShowAllMembers: function(oEvent) {
			if (! this._oDialog) {
				this._oDialog = sap.ui.xmlfragment("sap.ui.demo.mORMot.view.Members", this);
			}
			this.getView().addDependent(this._oDialog);

			// toggle compact style
			jQuery.sap.syncStyleClass("sapUiSizeCompact", this.getView(), this._oDialog);
			this._oDialog.open();
		},
		handleMembersSearch: function(oEvent) {
			var sValue = oEvent.getParameter("value");
			var oFilter = new Filter("LastName", sap.ui.model.FilterOperator.Contains, sValue);
			var oBinding = oEvent.getSource().getBinding("items");
			oBinding.filter([oFilter]);
		},
		handleMembersClose: function(oEvent) {
			this._oDialog.close;
			var aItem = oEvent.getParameter("selectedItem");
			var oBindContext = aItem.getBindingContext();
			
			console.log(oBindContext.getObject().Phone);
			console.log(oBindContext.getObject().ID);			
			
			var oModel = oBindContext.getModel();
			var sKey = oBindContext.getPath();
			// remove starting slash
			sKey = sKey.substr(1);
			var oNode = oModel.oData[sKey];			
			
			var aContexts = oEvent.getParameter("selectedContexts");
			if (aContexts.length) {
				MessageToast.show("You have chosen " + aContexts.map(function(oContext) { return oContext.getObject().LastName; }).join(", "));
			}
			oEvent.getSource().getBinding("items").filter([]);
			if (oNode) {
				this._router().navTo("Member", {TeamID: oNode.MemberTeam, MemberID: oNode.ID}, !Device.system.phone);				
			}
		} 		
	});
});
