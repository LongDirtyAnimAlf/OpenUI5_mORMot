/*!
 * UI development toolkit for HTML5 (OpenUI5)
 * (c) Copyright 2009-2015 SAP SE or an SAP affiliate company.
 * Licensed under the Apache License, Version 2.0 - see LICENSE.txt.
 */



// Provides class sap.ui.model.rest.RestMetadata
sap.ui.define(['jquery.sap.global', 'sap/ui/model/odata/ODataMetadata'],
	function(jQuery, ODataMetadata) {
	"use strict";

	var RestMetadata = ODataMetadata.extend("sap.ui.model.rest.RestMetadata", /** @lends sap.ui.model.rest.RestMetadata.prototype */ {
		constructor : function(sMetadataURI, mParams) {
			ODataMetadata.apply(this, arguments);

			// resolve promise !!
			this.fnResolve(mParams);

      // set namespace
			var aDummyNamespace = "dummy";
			
			// dummy values for the metadata object ... needed !!!
			this.oMetadata = {version : "0.0"};
			this.oMetadata.dataServices = {
				dataServiceVersion: "0.0",
				schema : [{
					entityContainer:[{
						entitySet:[],
						isDefaultEntityContainer:true,
						name:aDummyNamespace
					}],
					extensions:[{
						name: "lang",
						namespace: "http://www.w3.org/XML/1998/namespace",
						value: "en"
					}],
					entityType:[],
					namespace:aDummyNamespace
				}]
			};
		}
	});

	RestMetadata.prototype._getEntityTypeByPath = function(sPath) {
		if (!sPath) {
			jQuery.sap.assert(undefined, "sPath not defined!");
			return null;
		}
		
		if (!this.oMetadata || jQuery.isEmptyObject(this.oMetadata)) {
			jQuery.sap.assert(undefined, "No metadata loaded!");
			return null;
		}
		
		if (this.mEntityTypes[sPath]) {
			return this.mEntityTypes[sPath];
		}

		var	aEntityTypeName,
			oEntityType,
			that = this;

		var aParts = sPath.replace(/\/$/g, "").split("/");
		var i = (aParts.length)-1;
		i = i - ((i+1) % 2);
		var sCandidate = aParts[i];

		aEntityTypeName = this._splitName(this._getEntityTypeName(sCandidate));
		oEntityType = this._getObjectMetadata("entityType", aEntityTypeName[0], aEntityTypeName[1]);
		if (oEntityType) {
			// store the type name also in the oEntityType
			oEntityType.entityType = this._getEntityTypeName(sCandidate);
		}

		if (oEntityType) {
			this.mEntityTypes[sPath] = oEntityType;
		}

		//jQuery.sap.assert(oEntityType, "EntityType for path " + sPath + " could not be found!");
		return oEntityType;
	};

	return RestMetadata;
});
