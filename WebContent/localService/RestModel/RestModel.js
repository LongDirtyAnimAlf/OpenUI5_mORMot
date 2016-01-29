/*!
 * UI development toolkit for HTML5 (OpenUI5)
 * (c) Copyright 2009-2015 SAP SE or an SAP affiliate company.
 * Licensed under the Apache License, Version 2.0 - see LICENSE.txt.
 */

/**
 * REST-based Data Binding
 * This model an use a plain REST source without metadata and a standard REST data layout
 * (c) Copyright Don.  
 *
 * @namespace
 * @name sap.ui.model.rest
 * @public
 */

//Provides class sap.ui.model.rest.RestModel
sap.ui.define([
	'jquery.sap.global',
    'sap/ui/model/odata/v2/ODataModel',
    'sap/ui/model/Context',
    'sap/ui/model/odata/ODataUtils',
	'sap/ui/model/odata/CountMode', 'sap/ui/model/odata/UpdateMethod', 'sap/ui/model/odata/OperationMode'
	], function(
		jQuery,
		ODataModel,
		Context,
		ODataUtils,
		CountMode, UpdateMethod, OperationMode
		) {

	"use strict";


	/**
	 * Constructor for a new RestModel.
	 *
	 * @class
	 * (OData-)Model implementation for plain rest format
	 *
	 * @extends sap.ui.model.ODataModel
	 *
	 * @author Don
	 * @version 1.32.9
	 *
	 * @constructor
	 * @public
	 * @alias sap.ui.model.rest.RestModel
	 */
	var RestModel = ODataModel.extend("sap.ui.model.rest.RestModel", /** @lends sap.ui.model.rest.RestModel.prototype */ {

		constructor : function(sServiceUrl, mParameters) {
			
			var bmORMotRootResponse = false;
			var sKey;
			
			ODataModel.apply(this, arguments);

			// set some default to non odata  features
			this.bUseBatch = false;
			this.bJSON = true;
			//this.sDefaultCountMode = CountMode.None;
			//this.sDefaultCountMode = CountMode.Request;
			//this.sDefaultCountMode = CountMode.Inline;
			this.sDefaultCountMode = CountMode.Both
			//this.sDefaultOperationMode = OperationMode.Client;
			this.sDefaultOperationMode = OperationMode.Server;			
			//this.sDefaultOperationMode = OperationMode.Auto;
			this.sDefaultUpdateMethod = UpdateMethod.Put;
			
			this.bTokenHandling = false;
			
			this.bRefreshAfterChange = true;			
			
			this.oHeaders["Accept"] = "application/json";
			
			// remove trailing path delimiter if there
			this.sServiceUrl = this.sServiceUrl.replace(/\/$/g, "");			
			
		},
		metadata : {
			publicMethods : ["setKey","setmORMotRootResponse"]
		}
	});

	RestModel.prototype.setKey = function(sKey) {
		this.sKey = sKey;
	};
	
	RestModel.prototype.setmORMotRootResponse = function(bValue) {
		this.bmORMotRootResponse = bValue;
	};
	
	RestModel.prototype._processSuccess = function(oRequest, oResponse, fnSuccess, mGetEntities, mChangeEntities, mEntityTypes) {
		var oResultData = oResponse.data, bContent, sUri, sPath, that = this;
		
		var oFunctionResult;

		bContent = !(oResponse.statusCode === 204 || oResponse.statusCode === '204');
		
		// do we have data available
		// add uri and id into results !!
		if (bContent && oResultData !== undefined) {
			
			sUri = oRequest.requestUri;
			sPath = sUri.replace(this.sServiceUrl,"");
			//in batch requests all paths are relative
			if (!jQuery.sap.startsWith(sPath,'/')) {
				sPath = '/' + sPath;
			}
			sPath = this._normalizePath(sPath);
			// decrease laundering
			this.decreaseLaundering(sPath, oRequest.data);
			
			var oEntityType = that.oMetadata._getEntityTypeByPath(sPath);			
			
			// mORMot REST server: after a POST (new data), the new ID can be found here:
			var sNewKey = oResponse.headers["Location"];
			if (sNewKey) {
				sPath = "/"+sNewKey;
				oRequest.key = sPath; 
			}
			
			var sKey = oEntityType.key.propertyRef[0].name;
			var sType = oEntityType.entityType;			
			
			var sUriPath;
			
			if (jQuery.sap.endsWith(that.sServiceUrl,'/')) {
				sUriPath = that.sServiceUrl + sPath.substr(1);
			} else {
				sUriPath = that.sServiceUrl + sPath;
			}

			if (oResultData.results) {
				for (var attr in oResultData.results) {
					if ( (typeof oResultData.results[attr] === "object") && (oResultData.results[attr] !== null) ) {
						oResultData.results[attr].__metadata = {
								uri: sUriPath+"/"+oResultData.results[attr][sKey],
								id: sUriPath+"/"+oResultData.results[attr][sKey],
								type: sType						
							}
					}
				}
			} else {
				if ( (typeof oResultData === "object") && (oResultData !== null) ) {
					oResultData.__metadata = {
							uri: sUriPath,
							id: sUriPath,
							type: sType
					}
				}
			}
			
		}
		
		return ODataModel.prototype._processSuccess.apply(this, [oRequest, oResponse, fnSuccess, mGetEntities, mChangeEntities, mEntityTypes]);
	};

	// adapted for non odata REST servers	
	RestModel.prototype._getKey = function(oObject) {
		var sKey, sURI, that=this;
		if (oObject instanceof Context) {
			sKey = oObject.getPath().substr(1);
		} else if (oObject && oObject.__metadata && oObject.__metadata.uri) {
			sURI = oObject.__metadata.uri;			
			sKey = sURI.replace(that.sServiceUrl,"");
			if (jQuery.sap.startsWith(sKey, "/")) {
				sKey = sKey.substr(1);	
			};
		}
		return sKey;
	};

	// adapted for non odata REST servers	
	RestModel.prototype.getKey = function(oObject) {
		return this._getKey(oObject);
	};

	// first start of key creation
	// needed for full read/write
	// on my todo list
	RestModel.prototype.createKey = function(sCollection, oKeyProperties) {
		var oEntityType = this.oMetadata._getEntityTypeByPath(sCollection),
		sKey = sCollection;
		jQuery.sap.assert(oEntityType, "Could not find entity type of collection \"" + sCollection + "\" in service metadata!");
		sKey += "/"+oEntityType.key.propertyRef[0].name;
		return sKey;
	};
	
	// adapted for non odata REST servers 	
	RestModel.prototype._getObject = function(sPath, oContext, bOriginalValue) {
		var oNode = this.isLegacySyntax() ? this.oData : null, oChangedNode, oOrigNode,
			sResolvedPath = this.resolve(sPath, oContext),
			iSeparator, sDataPath, sMetaPath, oMetaContext, oMetaModel;
		
		var sKey;
		var sDataKey;

		//check for metadata path
		//if (this.oMetadata && this.oMetadata.isLoaded() && sResolvedPath && sResolvedPath.indexOf('/#') > -1)  {
		//	// Metadata binding resolved by ODataMetadata
		//	oNode = this.oMetadata._getAnnotation(sResolvedPath);
		//} else
		{
			if (!sResolvedPath) {
				return oNode;
			}

			var iIndex;
			var iDataIndex;
			var aParts = sResolvedPath.split("/");
			var iLength = aParts.length;

			// finding the key is complicated, when the REST scheme is not exactly known
			// below an algorithm to perform this task as good as possible !!
			// remains tricky
			
			iIndex = 1;
			iDataIndex = 1;
			while (aParts[iIndex] && (iIndex<(iLength-1) || (iIndex<3))) {
				if (sKey) {
					sKey = sKey + "/" + aParts[iIndex];				
				} else {
					sKey = aParts[iIndex];
				}
				iIndex++;
				if (this.oData[sKey]) {
					sDataKey = sKey;
					iDataIndex = iIndex;
				}
			}

			oOrigNode = this.oData[sKey];
			if (!oOrigNode && sDataKey && ((iIndex-iDataIndex)==1)) {
				sKey = sDataKey;
				iIndex = iDataIndex;
			}

			oOrigNode = this.oData[sKey];
			oChangedNode = this.mChangedEntities[sKey];

			aParts.splice(0,(iIndex));
			
			if (!bOriginalValue) {
				oNode = !sKey ? this.oData : oChangedNode || oOrigNode;
			} else {
				oNode = !sKey ? this.oData : oOrigNode;
			}

			iIndex = 0;		
			while (oNode && aParts[iIndex]) {
				var bHasChange = oChangedNode && oChangedNode.hasOwnProperty(aParts[iIndex]);
				oChangedNode = oChangedNode && oChangedNode[aParts[iIndex]];
				oOrigNode = oOrigNode && oOrigNode[aParts[iIndex]];
				oNode = bOriginalValue || !bHasChange ? oOrigNode : oChangedNode;
				if (oNode) {
					if (oNode.__ref) {
						oChangedNode = this.mChangedEntities[oNode.__ref];
						oOrigNode =  this.oData[oNode.__ref];
						oNode =  bOriginalValue ? oOrigNode : oChangedNode || oOrigNode;
					} else if (oNode.__list) {
						oNode = oNode.__list;
					} else if (oNode.__deferred) {
						// set to undefined and not to null because navigation properties can have a null value
						oNode = undefined;
					}
				}
				iIndex++;
			}
		}
		
		//if we have a changed Entity we need to extend it with the backend data
		if (this._getKey(oChangedNode)) {
			oNode =  bOriginalValue ? oOrigNode : jQuery.sap.extend(true, {}, oOrigNode, oChangedNode);
		}
		return oNode;
	};
	

	// send and retrieve data with standard OData ... some changes needed !! 
	RestModel.prototype._request = function(oRequest, fnSuccess, fnError) {

		if (
			(oRequest.requestUri.indexOf("null") > -1)
		) {
			return {
				abort: function() {}
			};
		}
		delete oRequest.headers["DataServiceVersion"]; // Remove odata header before call
		delete oRequest.headers["MaxDataServiceVersion"]; // Remove odata header before call

		if (oRequest.data) {
			if (oRequest.data.__metadata) {
				delete oRequest.data.__metadata;
			}
			//if (!jQuery.sap.startsWith(oRequest.headers["Content-Type"], "application/octet-stream")) {
			//	oRequest.data=JSON.stringify(oRequest.data);
			//} 			
		}
		
		//oRequest.requestUri = oRequest.requestUri.replace(":true",":1");		
		oRequest.requestUri = oRequest.requestUri.replace(":true",":\"true\"");		
		
		if (oRequest.requestUri.indexOf('$orderby')!=-1) {
			oRequest.requestUri = oRequest.requestUri.replace("%20asc","&dir=asc");		
			oRequest.requestUri = oRequest.requestUri.replace("%20desc","&dir=desc");
		}
		
		// server side filters: translate into (mORMot-) SQL commands
		
		// remove empty filter !!
		if (oRequest.requestUri.indexOf("$filter=()")!=-1) {
			oRequest.requestUri = oRequest.requestUri.replace("&$filter=()","");			
			oRequest.requestUri = oRequest.requestUri.replace("$filter=()&","");			
		}

		if (oRequest.requestUri.indexOf('$filter')!=-1) {
			oRequest.requestUri = oRequest.requestUri.replace("%20eq%20","%20=%20");
			oRequest.requestUri = oRequest.requestUri.replace("%20lt%20","%20<%20");
			oRequest.requestUri = oRequest.requestUri.replace("%20le%20","%20<=%20");		
			oRequest.requestUri = oRequest.requestUri.replace("%20gt%20","%20>%20");		
			oRequest.requestUri = oRequest.requestUri.replace("%20gt%20","%20>=%20");		
			oRequest.requestUri = oRequest.requestUri.replace("%20ne%20","%20<>%20");		

			var aFilter;		
			var aNewFilter;		
			
			while (oRequest.requestUri.indexOf('substringof')!=-1) {
				
				aFilter = oRequest.requestUri.substr(oRequest.requestUri.indexOf('substringof'));
				aFilter = aFilter.substr(0,aFilter.indexOf(')')+1);
				
				aNewFilter = aFilter.slice(aFilter.indexOf(',')+1,aFilter.indexOf(')'));
				aNewFilter = aNewFilter + "%20LIKE%20%27%25" + aFilter.slice(aFilter.indexOf("%27")+3,aFilter.lastIndexOf("%27"))+"%25%27";
					
				oRequest.requestUri = oRequest.requestUri.replace(aFilter,aNewFilter);			
			}
		}
		
		oRequest.requestUri = this.signUrl(oRequest.requestUri);		
		
		return ODataModel.prototype._request.apply(this, [oRequest, fnSuccess, fnError]);		
		
	};

	RestModel.prototype.isList = function(sPath, oContext) {
		sPath = this.resolve(sPath, oContext);
		return jQuery.isArray(this._getObject(sPath)); 		
	};
	
	RestModel.prototype._parseResponse = function(oResponse, oRequest, mGetEntities, mChangeEntities) {
		// no standard REST message parser in existence 
		//console.log("Response:");
		//console.log(oResponse);		
	};

	// update mORMot blobs like pictures and such
	RestModel.prototype.updateBlob = function(sPath, mParameters) {
		var oBlobData, fnSuccess, fnError, that = this;

		if (mParameters) {
			oBlobData = mParameters.BlobData;
			fnSuccess = mParameters.success;
			fnError   = mParameters.error;
		}
		
		function upload(sUrl,file) {
			  $.ajax({
			      url: sUrl,
			      method: 'PUT',
			      data: file,
			      //headers: {"Content-Type": "application/octet-stream"},
			      //contentType: false,
			      contentType: 'application/octet-stream',
			      processData: false,
			      cache: false,
			      async: true,
			      success: function(response, textStatus, xhr) {
			    	  fnSuccess(response,this,xhr);
			      },
			      error: function(xhr, textStatus, error) {
			    	  fnError(xhr);
			      }
			  });
		};		
		upload(that._createRequestUrl(sPath),oBlobData);
	};

	RestModel.prototype.signUrl = function(sUrl) {
		var sKey = sUrl.replace(this.mORMotClient.ServerURL,"");
		sKey = sKey.substr(1);		
		return this.mORMotClient.ServerURL +"/" + this.mORMotClient.signUrl(sKey);		
	};
	
	return RestModel;
});
