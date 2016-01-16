sap.ui.define([
	'sap/ui/demo/mORMot/localService/BaseController',
	'sap/ui/demo/mORMot/model/formatter',
	'sap/ui/model/Filter',
	'sap/ui/model/FilterOperator',
	'sap/ui/model/Sorter',
	'sap/m/Dialog',
	'sap/m/Button'
], function (BaseController,
			 formatter,
			 Filter,
			 FilterOperator,
			 Sorter,
			 Dialog,
			 Button) {
	"use strict";

	var oFirstNameSorter = new sap.ui.model.Sorter("FirstName", false, function (oContext) {
		var name = oContext.getProperty("FirstName");
		var sKey = name.charAt(0);
		var text = name.charAt(0);
		return {
			key: sKey, // group by first letter of firstname
			text: text
		};
	});
	var oLastNameSorter = new sap.ui.model.Sorter("LastName", false, function (oContext) {
		var name = oContext.getProperty("LastName");
		var sKey = name.charAt(0);
		var text = name.charAt(0);
		return {
			key: sKey, // group by first letter of lastname
			text: text
		};
	});
	
	return BaseController.extend("sap.ui.demo.mORMot.view.Home", {
		formatter : formatter,

		onInit: function () {
			this._search();
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
			
			oBinding.refresh();
			//that._search();
		},

		_search: function (sQuery) {
			var oView = this.getView();
			var oMemberList = oView.byId("MemberList");
			var oTeamList = oView.byId("TeamList");
			var oSortFirstNameButton = oView.byId("SortFirstNameButton");
			var oSortLastNameButton = oView.byId("SortLastNameButton");
			var oAddTeamButton = oView.byId("AddTeamButton");			
			
			var oSearchFieldValue = ( sQuery || oView.byId("searchField").getValue());			

			// switch visibility of lists and buttons
			
			var bShowSearch = oSearchFieldValue.length !== 0;
			oMemberList.toggleStyleClass("invisible", !bShowSearch);
			oTeamList.toggleStyleClass("invisible", bShowSearch);
			oSortFirstNameButton.toggleStyleClass("invisible", !bShowSearch);
			oSortLastNameButton.toggleStyleClass("invisible", !bShowSearch);			
			oAddTeamButton.toggleStyleClass("invisible", bShowSearch);			

			if (bShowSearch) {
				this._changeNoDataTextToIndicateLoading(oMemberList);
			}

			// filter Member list
			var oBinding = oMemberList.getBinding("items");
			if (oBinding) {
			
				if (!bShowSearch) {
					// reset sorter
					oBinding.sort();
				}

				if (bShowSearch) {
					var oFilter = [new sap.ui.model.Filter("FirstName", sap.ui.model.FilterOperator.Contains, oSearchFieldValue),new sap.ui.model.Filter("LastName", sap.ui.model.FilterOperator.Contains, oSearchFieldValue)];
					// needed because we want to OR the filters !!
					var allFilters = new sap.ui.model.Filter(oFilter, false);
					oBinding.filter(allFilters);
				} else {
					oBinding.filter([]);
				}
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
			var oView = this.getView();
			var oMemberList = oView.byId("MemberList");
			//var oItem = oEvent.getSource();
			var oBinding = oMemberList.getBinding("items");
			oBinding.sort(oFirstNameSorter);			
		},

		handleMemberSortLastNameButtonPress: function (oEvent) {
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
		}
		
	});
});
