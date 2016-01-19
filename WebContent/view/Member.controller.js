sap.ui.define([
    'jquery.sap.global',               
	'sap/ui/demo/mORMot/localService/BaseController',
	'sap/ui/demo/mORMot/model/formatter',
	'sap/m/MessageToast',
	'sap/m/MessageBox'
], function (jQuery,BaseController, formatter, MessageToast, MessageBox) {
	return BaseController.extend("sap.ui.demo.mORMot.view.Member", {
		formatter : formatter,

		formatImageUrl: function(sID) {
			var	oView = this.getView();
			var oModel = oView.getModel();
			return oModel.sServiceUrl.replace(/\/$/g, "")+"/Member/" + sID + "/Image";						
		},
		
		_sTeamId : 0,
		
		onInit : function () {
			this._router().getRoute("Member").attachPatternMatched(this._routePatternMatched, this);
			this._router().getRoute("TeamMember").attachPatternMatched(this._routePatternMatched, this);
		},

		onAfterRendering : function() {
			//var path = "/Member/1/Image";
			//var image = this.getView().byId("realImage");			
			//var image = $("#realImage");
			//console.log("RENDERER !!!");
			//image.bindProperty("src", path);
			
			//image.bindProperty("src", "/company/trusted", function(bValue) {
			//    return bValue ? "green.png" : "red.png";
			//}); 			
			
			//console.log(image);			
			//image.attr("src", path);
		},  

		_routePatternMatched: function(oEvent) {
			var sId = oEvent.getParameter("arguments").MemberID;
			this._sTeamId = (oEvent.getParameter("arguments").TeamID || 0);
			var	oView = this.getView();
			var oModel = oView.getModel();
			var sPath = "/Member/"+sId;
			var oData = oModel.getData(sPath);
			
			var oImage = oView.byId("realImage2");			
			oImage.setSrc(oModel.sServiceUrl.replace(/\/$/g, "")+sPath+"/Image");  			
			
			oView.bindElement({
				path: sPath,
				events: {
					dataRequested: function () {
						oView.setBusy(true);
					},
					dataReceived: function () {
						oView.setBusy(false);
					}
				}
				,parameters : {select:'ID,FirstName,LastName,Address,Zip,City,PictureUrl,Phone,Email',key:'ID'}
			});
			
			//if there is no data the model has to request new data
			if (!oData) {
				oView.setBusyIndicatorDelay(0);
				oView.getElementBinding().attachEventOnce("dataReceived", function() {
					// reset to default
					oView.setBusyIndicatorDelay(null);
					this._checkIfMemberAvailable(sPath, sId);
				}.bind(this));
			}
		},
		
		onShowResume : function (oEvent) {
			var that = this;
			var oData = this.getView().getBindingContext().getProperty();
			if (oData) {
				if (this._sTeamId>0) {
					this._router().navTo("MemberResume", {
						TeamID : this._sTeamId, MemberID : oData.ID				
					});
				} else {
					this._router().navTo("TeamMemberResume", {
						MemberID : oData.ID				
					});
				}
			}
		},
		
		_checkIfMemberAvailable: function(sPath, sId) {
			var oModel = this.getView().getModel();
			// remove starting slash
			var sKey = sPath.substr(1);
			var oData = oModel.oData[sKey];
			if (!oData) {
				// show not found page				
				this._router().getTargets().display("notFound", sId);
			}
		},

		handleMemberCallButtonPress: function() {
			var oData = this.getView().getBindingContext().getProperty();
			if (oData.Phone) {			
				sap.m.URLHelper.triggerTel(oData.Phone);
			}
		},

		handleMemberTextButtonPress: function() {
			var oData = this.getView().getBindingContext().getProperty();
			if (oData.Phone) {
				sap.m.URLHelper.triggerSms(oData.Phone);
			}
		},

		handleMemberMailButtonPress: function() {
			var oData = this.getView().getBindingContext().getProperty();
			if (oData.Email) {
				sap.m.URLHelper.triggerEmail(oData.Email);				
			}
		},
		
		onUpdate: function() {
			var oView = this.getView();
			var oBinding = oView.getBindingContext();
			var oProperty = oBinding.getProperty();
			var sPath = oBinding.getPath();
			var oModel = oView.getModel();

			// Does already work !!!
			// But disable for now ... more tests needed. 			
			//oModel.submitChanges();
			oModel.submitChanges({ 
				success: function(){
					sap.m.MessageToast.show("Update successfull");					
 				},
 				error: function(){
 					alert("Update failed");
 				}
 			});
			
			/*
			var mUserData = {};
			// make a copy of the original ... not really needed ...
			//var mUserData = jQuery.extend(true, {}, oProperty);
			
			mUserData.Email = "iamhappy@gmail.com";
			
			mUserData.Country = sPath;

			//mUserData.Email = oView.byId("Email").getValue();
			//mUserData.FirstName = oView.byId("FirstName").getValue();
			//mUserData.LastName = oView.byId("LastName").getValue();
			//mUserData.Phone = oView.byId("Phone").getValue();
			//mUserData.Address = oView.byId("Address").getValue();			

		    oModel.update(sPath, mUserData, {
		      success: jQuery.proxy(function(mResponse) {
		    	  sap.m.MessageToast.show("Update success !!");
		    	  //oModel.refresh();
		    	  oView.getElementBinding().refresh();		    	  
		      }, this),
		      error: jQuery.proxy(function() {
		        alert("Problem updating user");
		      }, this)
		    });
		    */
			
		},
		
		onCancel: function() {
			var oView = this.getView();
			var oModel = oView.getModel();
			var oBinding = oView.getBindingContext();
			var oProperty = oBinding.getProperty();
			var sPath = oBinding.getPath();
			oModel.resetChanges([sPath]);
		},

		onDelete: function() {
			var oView = this.getView();
			var oBinding = oView.getBindingContext();
			var sPath = oBinding.getPath();
			var oModel = oView.getModel();
			var that = this;

			oModel.remove(sPath, {
				success: function() {
					sap.m.MessageToast.show("Delete successfull");
					//that.handleNavButtonPress;
					oModel.refresh();
					//oView.getElementBinding().refresh();				
					//oView.getElementBinding().refresh();				
				},
				error: function() {
					alert("Delete failed");
				}
			});
		},
		
		handleValueChange: function() {
			var oView = this.getView();
			var oModel = oView.getModel();
			var oBinding = oView.getBindingContext();
			var oProperty = oBinding.getProperty();
			var sPath = oBinding.getPath()+"/Image";
			var sURL = oModel.sServiceUrl.replace(/\/$/g, "")+sPath;						
			var oFileUploader = oView.byId("fileUploader");
			var f = oFileUploader.oFileUpload.files[0];
			if (f) {  
				 var r = new FileReader();
				 r.onload = function(e) {
					 var fileContent = e.target.result;
					 	oModel.updateBlob(sPath,{
					 			BlobData:fileContent,
					 			success: function() {
					 				sap.m.MessageToast.show("Update blob successfull");
					 				oModel.refresh();
					 			},
					 			error: function() {
					 				alert("Update blob failed");
					 			}
					 		}
					 	);
				 };  
				 r.readAsArrayBuffer(f);
			}  
		}	
	});
});
