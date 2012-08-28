package pixelizer {
	import __AS3__.vec.Vector;
	import flash.system.System;
	import pixelizer.components.collision.PxColliderComponent;
	import pixelizer.IPxEntityContainer;
	import pixelizer.physics.PxCollisionSystem;
	import pixelizer.render.PxCamera;
	import pixelizer.sound.PxSoundSystem;
	import pixelizer.systems.PxSystem;
	import pixelizer.utils.PxMath;
	
	/**
	 * The scene holds and manages all entities. Scenes are updated by the engine.
	 *
	 * @author Johan Peitz
	 */
	public class PxScene implements IPxEntityContainer {
		private var _entityRoot : PxEntity;
		
		/**
		 * Systems running on current scene.
		 */
		private var _systems : Array;
		protected var _collisionSystem : PxCollisionSystem;
		protected var _soundSystem : PxSoundSystem;
		protected var _inputSystem: PxInputSystem;
		
		private var _mainCamera : PxCamera;
		
		/**
		 * Specifies whether the scene has a background fill.
		 */
		public var background : Boolean = true;
		/**
		 * The color of the backround, if any.
		 */
		public var backgroundColor : int = 0xFFFFFF;
		/**
		 * Engine scene is added to.
		 */
		public var engine : PxEngine = null;
		
		/**
		 * Constructs a new scene.
		 */
		public function PxScene() {
			_entityRoot = new PxEntity();
			_entityRoot.scene = this;
			
			_systems = [];
			_inputSystem = addSystem( new PxInputSystem( this, 100 ) ) as PxInputSystem;
			_collisionSystem = addSystem( new PxCollisionSystem( this, 200 ) ) as PxCollisionSystem;
			_soundSystem = addSystem( new PxSoundSystem( this, 300 ) ) as PxSoundSystem;
			
			_mainCamera = new PxCamera( Pixelizer.engine.width, Pixelizer.engine.height, -Pixelizer.engine.width / 2, -Pixelizer.engine.height / 2 );
		}
		
		/**
		 * Cleans up all resources used by the scene, including any added entities which will also be disposed.
		 */
		public function dispose() : void {

			_entityRoot.dispose();
			_entityRoot = null;
			
			_mainCamera.dispose();
			_mainCamera = null;
			
			for each ( var s : PxSystem in _systems ) {
				s.dispose();
			}
			_systems = null;

			engine = null;
		}
		
		/**
		 * Invoked when the scene is added to the engine.
		 * @param	pEngine	The engine the scene is added to.
		 */
		public function onAddedToEngine( pEngine : PxEngine ) : void {
			engine = pEngine;
		}
		
		/**
		 * Invoked when the scene is remove from an engine. Disposes the scene.
		 */
		public function onRemovedFromEngine() : void {
			engine = null;
			dispose();
		}
		
		public function onActivated():void 
		{
			_soundSystem.unpause();
			_inputSystem.reset();
		}
		
		public function onDeactivated():void 
		{
			_soundSystem.pause();
		}
		
		
		/**
		 * Invoked regularly by the engine. Updates all entities and subsystems.
		 * @param	pDT	Time step in number of seconds.
		 */
		public function update( pDT : Number ) : void {
			// update entities
			updateEntityTree( _entityRoot, pDT );
			
			// update all systems
			for each ( var s : PxSystem in _systems ) {
				s.update( pDT );
			}
			
			if ( _mainCamera != null ) {
				_mainCamera.update( pDT );
			}
		
		}
		
		private function updateEntityTree( pEntity : PxEntity, pDT : Number ) : void {
			engine.logicStats.entitiesUpdated++;
			
			pEntity.update( pDT );
			
			for each ( var e : PxEntity in pEntity.entities ) {
				e.transform.rotationOnScene = pEntity.transform.rotationOnScene + e.transform.rotation;
				
				e.transform.scaleXOnScene = pEntity.transform.scaleXOnScene * e.transform.scaleX;
				e.transform.scaleYOnScene = pEntity.transform.scaleYOnScene * e.transform.scaleY;
				
				e.transform.positionOnScene.x = pEntity.transform.positionOnScene.x;
				e.transform.positionOnScene.y = pEntity.transform.positionOnScene.y;
				
				if ( e.transform.rotationOnScene == 0 ) {
					e.transform.positionOnScene.x += e.transform.position.x * pEntity.transform.scaleXOnScene;
					e.transform.positionOnScene.y += e.transform.position.y * pEntity.transform.scaleXOnScene;
				} else {
					// TODO: find faster versions of sqrt and atan2
					var d : Number = Math.sqrt( e.transform.position.x * e.transform.position.x + e.transform.position.y * e.transform.position.y );
					var a : Number = Math.atan2( e.transform.position.y, e.transform.position.x ) + pEntity.transform.rotationOnScene;
					e.transform.positionOnScene.x += d * PxMath.cos( a ) * pEntity.transform.scaleXOnScene;
					e.transform.positionOnScene.y += d * PxMath.sin( a ) * pEntity.transform.scaleYOnScene;
				}
				
				updateEntityTree( e, pDT );
			}
			
			if ( pEntity.destroy ) {
				pEntity.parent.removeEntity( pEntity );
			}
		}
		
		/**
		 * Returns the camera for this scene.
		 */
		public function get camera() : PxCamera {
			return _mainCamera;
		}
		
		/**
		 * Returns the root entity to which all other entities are added.
		 * @return 	The root entity.
		 */
		public function get entityRoot() : PxEntity {
			return _entityRoot;
		}
		
		public function get collisionSystem() : PxCollisionSystem {
			return _collisionSystem;
		}
		
		public function get soundSystem() : PxSoundSystem {
			return _soundSystem;
		}
		
		public function get inputSystem():PxInputSystem 
		{
			return _inputSystem;
		}
		
		/**
		 * Adds and entity to the scene.
		 * @param	pEntity The entity to add.
		 * @return	The entity parameter passed as argument.
		 */
		public function addEntity( pEntity : PxEntity, pHandle : String = "" ) : PxEntity {
			return _entityRoot.addEntity( pEntity, pHandle );
		}
		
		/**
		 * Removes an entity from the scene. The entity will be disposed.
		 * @param	pEntity	The entity to remove.
		 * @return	The entity parameter passed as argument.
		 */
		public function removeEntity( pEntity : PxEntity ) : PxEntity {
			return _entityRoot.removeEntity( pEntity );
		}
		
		/**
		 * Adds entities of the desired class to the specified vector.
		 * @param	pRootEntity		Root entity of where to start the search. ( E.g. scene.entityRoot )
		 * @param	pEntityClass	The entity class to look for.
		 * @param	pEntityVector	Vector to populate with the results.
		 */
		public function getEntitesByClass( pRootEntity : PxEntity, pEntityClass : Class, pEntityVector : Vector.<PxEntity> ) : void {
			return _entityRoot.getEntitesByClass( pRootEntity, pEntityClass, pEntityVector );
		}
		
		/**
		 * Adds entities with the specified handle to the specified vector.
		 * @param	pRootEntity	Root entity of where to start the search. ( E.g. scene.entityRoot )
		 * @param	pHandle	Handle to look for.
		 * @param	pEntityVector	Vector to populate with the results.
		 */
		public function getEntitiesByHandle( pRootEntity : PxEntity, pHandle : String, pEntityVector : Vector.<PxEntity> ) : void {
			return _entityRoot.getEntitiesByHandle( pRootEntity, pHandle, pEntityVector );
		}
		
		public function forEachEntity( pEntityRoot : PxEntity, pFunction : Function ) : void {
			pFunction( pEntityRoot );
			for each ( var e : PxEntity in pEntityRoot.entities ) {
				forEachEntity( e, pFunction );
			}
		}
		
		public function removeSystem( pSystem : PxSystem ) : PxSystem {
			_systems.splice( _systems.indexOf( pSystem ), 1 );
			return pSystem;
		}
	
		public function addSystem( pSystem : PxSystem ) : PxSystem {
			_systems.push( pSystem );
			_systems.sort( PxSystem.sortOnPriority );
			return pSystem;
		}
		
	
	}
}