sap.ui.define([
	'sap/ui/core/UIComponent',
	'sap/m/routing/Router',
	'sap/ui/model/resource/ResourceModel',
	'sap/ui/model/json/JSONModel',
    'sap/ui/demo/mORMot/model/Config',
	'sap/ui/demo/mORMot/localService/mORMot/mORMotModel'    
], function (UIComponent,
			Router,
			ResourceModel,
			JSONModel,
			mORMotModel) {

	return UIComponent.extend("sap.ui.demo.mORMot.Component", {

		metadata: {
			includes : ["css/style.css"],
			routing: {
				config: {
					routerClass: Router,
					viewType: "XML",
					viewPath: "sap.ui.demo.mORMot.view",
					controlId: "splitApp",
					transition: "slide",
					bypassed: {
						target: ["home" , "notFound"]
					}
				},
				routes: [
					{
						pattern: "",
						name: "home",
						target: "home"
					},
					{
						pattern: "Team/{TeamID}",
						name: "Team",
						target: "TeamView"
					},
					{
						pattern: "Team/{TeamID}/Member/{MemberID}",
						name: "Member",
						target: ["TeamView", "MemberView"]
					},
					{
						pattern: "Member/{MemberID}",
						name: "TeamMember",
						target: ["home" , "MemberView"]
					},
					{
						pattern: "Member/{MemberID}/resume",
						name: "MemberResume",
						target: ["home", "MemberResume"]
					},
					{
						pattern: "Team/{TeamID}/Member/{MemberID}/resume",
						name: "MemberResume",
						target: ["TeamView", "MemberResume"]							
					}
				],
				targets: {
					MemberView: {
						viewName: "Member",
						viewLevel: 3,
						controlAggregation: "detailPages"
					},
					TeamView: {
						viewName: "Team",
						viewLevel: 2,
						controlAggregation: "masterPages"
					},
					notFound: {
						viewName: "NotFound",
						viewLevel: 3,
						controlAggregation: "detailPages"
					},
					welcome: {
						viewName: "Welcome",
						viewLevel: 0,
						controlAggregation: "detailPages"
					},
					home: {
						viewName: "Home",
						viewLevel: 1,
						controlAggregation: "masterPages"
					},
					MemberResume: {
						viewName: "MemberResume",
						viewLevel : 4,
						transition: "flip",
						controlAggregation: "detailPages"							
					}
				}
			}
		},

		init: function () {
			// call overwritten init (calls createContent)
			UIComponent.prototype.init.apply(this, arguments);

			// set i18n model
			var oI18nModel = new ResourceModel({
				bundleName: "sap.ui.demo.mORMot.i18n.appTexts"
			});
			this.setModel(oI18nModel, "i18n");

			var oModel = new sap.ui.model.mORMot.mORMotModel(model.Config.getServiceUrl("/root/"));
			oModel.setUseBatch(false);

			this.setModel(oModel);

			// set device model
			var oDeviceModel = new JSONModel({
				isTouch: sap.ui.Device.support.touch,
				isNoTouch: !sap.ui.Device.support.touch,
				isPhone: sap.ui.Device.system.phone,
				isNoPhone: !sap.ui.Device.system.phone,
				listMode: (sap.ui.Device.system.phone) ? "None" : "SingleSelectMaster",
				listItemType: (sap.ui.Device.system.phone) ? "Active" : "Inactive"
			});
			oDeviceModel.setDefaultBindingMode("OneWay");
			this.setModel(oDeviceModel, "device");

			this._router = this.getRouter();

			//navigate to initial page for !phone
			if (!sap.ui.Device.system.phone) {
				this._router.getTargets().display("welcome");
			}

			// initialize the router
			this._router.initialize();

		},

		createContent: function () {
			// create root view
			return sap.ui.view({
				viewName: "sap.ui.demo.mORMot.view.App",
				type: "XML"
			});
		}
	});

});
