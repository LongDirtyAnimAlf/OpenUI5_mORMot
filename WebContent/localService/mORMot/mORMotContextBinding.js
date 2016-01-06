/*!
 * UI development toolkit for HTML5 (OpenUI5)
 * (c) Copyright 2009-2015 SAP SE or an SAP affiliate company.
 * Licensed under the Apache License, Version 2.0 - see LICENSE.txt.
 */

//Provides an abstraction for list bindings
sap.ui.define(['jquery.sap.global', 'sap/ui/model/ContextBinding'],
		function(jQuery, ContextBinding) {
	"use strict";


	/**
	 * Constructor for mORMot.mORMotContextBinding
	 *
	 * @class
	 * The ContextBinding is a specific binding for a setting context for the model
	 *
	 * @param {sap.ui.model.Model} oModel
	 * @param {String} sPath
	 * @param {Object} oContext
	 * @param {Object} [mParameters]
	 * @abstract
	 * @public
	 * @alias sap.ui.model.mORMot.mORMotContextBinding
	 */
	var mORMotContextBinding = ContextBinding.extend("sap.ui.model.mORMot.mORMotContextBinding", /** @lends sap.ui.model.mORMot.mORMotContextBinding.prototype */ {

		constructor : function(oModel, sPath, oContext, mParameters, oEvents){
			ContextBinding.call(this, oModel, sPath, oContext, mParameters, oEvents);
			console.log("mORMotContextBinding constructor");
			this.bRefreshGroupId = undefined;
		}
	});

	/**
	 * Initializes the binding, will create the binding context.
	 * If metadata is not yet available, do nothing, method will be called again when
	 * metadata is loaded.
	 * @see sap.ui.model.Binding.prototype.initialize
	 */
	mORMotContextBinding.prototype.initialize = function() {
		var that = this;
		var	sResolvedPath = this.oModel.resolve(this.sPath, this.oContext);
		var	oData = this.oModel._getObject(this.sPath, this.oContext);
		var bReloadNeeded = this.oModel._isReloadNeeded(sResolvedPath, oData, this.mParameters);

		console.log("mORMotContextBinding.prototype.initialize");		
		
		if (sResolvedPath && bReloadNeeded) {
			this.fireDataRequested();
		}
		this.oModel.createBindingContext(this.sPath, this.oContext, this.mParameters, function(oContext) {
			that.oElementContext = oContext;
			that._fireChange();
			if (sResolvedPath && bReloadNeeded) {
				if (that.oElementContext) {
					oData = that.oElementContext.getObject();
				}
				//register datareceived call as  callAfterUpdate
				that.oModel.callAfterUpdate(function() {
					that.fireDataReceived({data: oData});
				});
			}
		}, bReloadNeeded);
		this.bInitial = false;
	};
	/**
	 * @see sap.ui.model.ContextBinding.prototype.refresh
	 * 
	 * @param {boolean} [bForceUpdate] Update the bound control even if no data has been changed
	 * @param {string} [sGroupId] The group Id for the refresh
	 * 
	 * @public
	 */
	mORMotContextBinding.prototype.refresh = function(bForceUpdate, sGroupId) {
		if (typeof bForceUpdate === "string") {
			sGroupId = bForceUpdate;
			bForceUpdate = false;
		}
		this.sRefreshGroup = sGroupId;
		this._refresh(bForceUpdate);
		this.sRefreshGroup = undefined;
	};
	
	/**
	 * @see sap.ui.model.ContextBinding.prototype.refresh
	 * 
	 * @param {boolean} [bForceUpdate] Update the bound control even if no data has been changed
	 * @param {map} [mChangedEntities] Map of changed entities
	 * @private
	 */
	mORMotContextBinding.prototype._refresh = function(bForceUpdate, mChangedEntities) {
		var that = this, oData, sKey, oStoredEntry, bChangeDetected = false, 
			mParameters = this.mParameters,
			sResolvedPath = this.oModel.resolve(this.sPath, this.oContext);

		if (this.bInitial) {
			return;
		}
		
		if (mChangedEntities) {
			//get entry from model. If entry exists get key for update bindings
			oStoredEntry = this.oModel._getObject(this.sPath, this.oContext);
			if (oStoredEntry) {
				sKey = this.oModel._getKey(oStoredEntry);
				if (sKey in mChangedEntities) {
					bChangeDetected = true;
				}
			}
		} else { // default
			bChangeDetected = true;
		}
		if (bForceUpdate || bChangeDetected) {
			//recreate Context: force update
			if (sResolvedPath) {
				this.fireDataRequested();
			}
			if (this.sRefreshGroup) {
				mParameters = jQuery.extend({},this.mParameters);
				mParameters.groupId = this.sRefreshGroup;
			} 
			this.oModel.createBindingContext(this.sPath, this.oContext, mParameters, function(oContext) {
				if (that.oElementContext === oContext) {
					if (bForceUpdate) {
						that._fireChange();
					}
				} else {
					that.oElementContext = oContext;
					that._fireChange();
				}
				if (that.oElementContext) {
					oData = that.oElementContext.getObject();
				}
				//register datareceived call as  callAfterUpdate
				if (sResolvedPath) {
					that.oModel.callAfterUpdate(function() {
						that.fireDataReceived({data: oData});
					});
				}
			}, true);
		}
	};

	/**
	 * @see sap.ui.model.ContextBinding.prototype.setContext
	 * 
	 * @param {sap.ui.model.Context} oContext The binding context object
	 * @private
	 */
	mORMotContextBinding.prototype.setContext = function(oContext) {
		var that = this,
			oData,
			sResolvedPath,
			oData,
			bReloadNeeded;

		if (this.oContext !== oContext && this.isRelative()) {
			this.oContext = oContext;
			sResolvedPath = this.oModel.resolve(this.sPath, this.oContext);
			oData = this.oModel._getObject(this.sPath, this.oContext);
			bReloadNeeded = this.oModel._isReloadNeeded(sResolvedPath, oData, this.mParameters);

			// don't fire any requests if metadata is not loaded yet.
			if (!this.bInitial) {
				if (sResolvedPath && bReloadNeeded) {
					this.fireDataRequested();
				}
				this.oModel.createBindingContext(this.sPath, this.oContext, this.mParameters, function(oContext) {
					that.oElementContext = oContext;
					that._fireChange();
					if (sResolvedPath && bReloadNeeded) {
						if (that.oElementContext) {
							oData = that.oElementContext.getObject();
						}
						//register datareceived call as  callAfterUpdate
						that.oModel.callAfterUpdate(function() {
							that.fireDataReceived({data: oData});
						});
					}
				}, bReloadNeeded);
			}
		}
	};

	return mORMotContextBinding;

});
