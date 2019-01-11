/**
 * Copyright (c) 2016 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import SpriteKit
import GameplayKit

class GameScene: SKScene {

    // constants
    let waterMaxSpeed: CGFloat = 200
    let landMaxSpeed: CGFloat = 4000

    // if within threshold range of the target, car begins slowing
    let targetThreshold:CGFloat = 200

    var maxSpeed: CGFloat = 0
    var acceleration: CGFloat = 0

    // touch location
    var targetLocation: CGPoint = .zero

    // Scene Nodes
    var car:SKSpriteNode!

    var landBackground: SKTileMapNode!
    var objectsTileMap: SKTileMapNode!

    lazy var duckSound: SKAction = {
        return SKAction.playSoundFileNamed("Duck.wav", waitForCompletion: false)
    }()

    lazy var gascanSound: SKAction = {
        return SKAction.playSoundFileNamed("Gas.wav", waitForCompletion: false)
    }()

    override func didMove(to view: SKView) {
        loadSceneNodes()
        physicsBody = SKPhysicsBody(edgeLoopFrom: frame)
        maxSpeed = landMaxSpeed
        setupObjects()
    }

    func loadSceneNodes() {
        guard let car = childNode(withName: "car") as? SKSpriteNode else {
            fatalError("Sprite Nodes not loaded")
        }
        guard let landBackground = childNode(withName: "landBackground") as? SKTileMapNode else {
            fatalError("Background node not loaded")
        }
        self.car = car
        self.landBackground = landBackground
    }

    func setupObjects() {
        let columns = 32
        let rows = 24
        let size = CGSize(width: 64, height: 64)

        guard let tileSet = SKTileSet(named: "Object Tiles") else {
            fatalError("Object Tiles Tile Set not found")
        }

        objectsTileMap = SKTileMapNode(tileSet: tileSet, columns: columns, rows: rows, tileSize: size)
        addChild(objectsTileMap)

        let tileGroups = tileSet.tileGroups
        guard let duckTile = tileGroups.first(where: { $0.name == "Duck" }) else {
            fatalError("No Duck tile definition found")
        }
        guard let gascanTile = tileGroups.first(where: { $0.name == "Gas Can" }) else {
            fatalError("No Gas Can tile definition found")
        }

        let numberOfObjects = 64

        for _ in 1...numberOfObjects {
            let column = Int.random(in: 0..<columns)
            let row = Int.random(in: 0..<rows)

            let groundTile = landBackground.tileDefinition(atColumn: column, row: row)
            let tile = groundTile == nil ? duckTile : gascanTile

            objectsTileMap.setTileGroup(tile, forColumn: column, row: row)
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        targetLocation = touch.location(in: self)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        targetLocation = touch.location(in: self)
    }


    override func update(_ currentTime: TimeInterval) {
        let position = car.position
        let column = landBackground.tileColumnIndex(fromPosition: position)
        let row = landBackground.tileRowIndex(fromPosition: position)
        let tile = landBackground.tileDefinition(atColumn: column, row: row)

        if tile == nil {
            maxSpeed = waterMaxSpeed
        } else {
            maxSpeed = landMaxSpeed
        }

        let objectTile = objectsTileMap.tileDefinition(atColumn: column, row: row)

        if let _ = objectTile?.userData?.value(forKey: "gascan") {
            run(gascanSound)
            objectsTileMap.setTileGroup(nil, forColumn: column, row: row)
        }

        if let _ = objectTile?.userData?.value(forKey: "duck") {
            run(duckSound)
            objectsTileMap.setTileGroup(nil, forColumn: column, row: row)
        }
    }

    override func didSimulatePhysics() {

        let offset = CGPoint(x: targetLocation.x - car.position.x,
                             y: targetLocation.y - car.position.y)
        let distance = sqrt(offset.x * offset.x + offset.y * offset.y)
        let carDirection = CGPoint(x:offset.x / distance,
                                   y:offset.y / distance)
        let carVelocity = CGPoint(x: carDirection.x * acceleration,
                                  y: carDirection.y * acceleration)

        car.physicsBody?.velocity = CGVector(dx: carVelocity.x, dy: carVelocity.y)

        if acceleration > 5 {
            car.zRotation = atan2(carVelocity.y, carVelocity.x)
        }

        // update acceleration
        // car speeds up to maximum
        // if within threshold range of the target, car begins slowing
        // if maxSpeed has reduced due to different tiles,
        // may need to decelerate slowly to the new maxSpeed

        if distance < targetThreshold {
            let delta = targetThreshold - distance
            acceleration = acceleration * ((targetThreshold - delta)/targetThreshold)
            if acceleration < 2 {
                acceleration = 0
            }
        } else {
            if acceleration > maxSpeed {
                acceleration -= min(acceleration - maxSpeed, 80)
            }
            if acceleration < maxSpeed {
                acceleration += min(maxSpeed - acceleration, 40)
            }
        }

    }
}
