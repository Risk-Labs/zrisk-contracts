// Core imports

use debug::PrintTrait;

// Starknet imports

use starknet::testing::set_contract_address;

// Dojo imports

use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports

use zrisk::config;
use zrisk::datastore::{DataStore, DataStoreTrait};
use zrisk::components::game::{Game, GameTrait};
use zrisk::components::player::Player;
use zrisk::components::tile::Tile;
use zrisk::systems::create::ICreateDispatcherTrait;
use zrisk::systems::supply::ISupplyDispatcherTrait;
use zrisk::systems::finish::IFinishDispatcherTrait;
use zrisk::systems::attack::IAttackDispatcherTrait;
use zrisk::tests::setup::{setup, setup::Systems};

// Constants

const ACCOUNT: felt252 = 'ACCOUNT';
const SEED: felt252 = 'SEED';
const NAME: felt252 = 'NAME';
const PLAYER_COUNT: u8 = 2;
const PLAYER_INDEX: u8 = 0;

#[test]
#[available_gas(1_000_000_000)]
fn test_attack() {
    // [Setup]
    let (world, systems) = setup::spawn_game();
    let mut datastore = DataStoreTrait::new(world);

    // [Create]
    systems.create.create(world, ACCOUNT, SEED, NAME, PLAYER_COUNT);

    // [Compute] Attacker tile
    let game: Game = datastore.game(ACCOUNT);
    let initial_player: Player = datastore.player(game, PLAYER_INDEX);
    let supply = initial_player.supply.into();
    let mut attacker: u8 = 1;
    let army = loop {
        let tile: Tile = datastore.tile(game, attacker.into());
        if tile.owner == PLAYER_INDEX.into() {
            break tile.army;
        }
        attacker += 1;
    };

    // [Supply]
    systems.supply.supply(world, ACCOUNT, attacker, supply);

    // [Finish]
    systems.finish.finish(world, ACCOUNT);

    // [Compute] Defender tile
    let mut neighbors = config::neighbors(attacker).expect('Attack: invalid tile id');
    let mut defender = loop {
        match neighbors.pop_front() {
            Option::Some(index) => {
                let tile: Tile = datastore.tile(game, *index);
                if tile.owner != PLAYER_INDEX.into() {
                    break tile.index;
                }
            },
            Option::None => {
                panic(array!['Attack: defender not found']);
            },
        };
    };

    // [Attack]
    let distpached: u32 = (army + supply - 1).into();
    systems.attack.attack(world, ACCOUNT, attacker, defender, distpached);
}


#[test]
#[available_gas(1_000_000_000)]
#[should_panic(expected: ('Attack: invalid player', 'ENTRYPOINT_FAILED',))]
fn test_attack_revert_invalid_player() {
    // [Setup]
    let (world, systems) = setup::spawn_game();
    let mut datastore = DataStoreTrait::new(world);

    // [Create]
    systems.create.create(world, ACCOUNT, SEED, NAME, PLAYER_COUNT);

    // [Compute] Tile army and player available supply
    let game: Game = datastore.game(ACCOUNT);
    let initial_player: Player = datastore.player(game, PLAYER_INDEX);
    let supply: u32 = initial_player.supply.into();
    let mut tile_index: u8 = 1;
    loop {
        let tile: Tile = datastore.tile(game, tile_index.into());
        if tile.owner == PLAYER_INDEX.into() {
            break;
        }
        tile_index += 1;
    };

    // [Supply]
    systems.supply.supply(world, ACCOUNT, tile_index, supply);

    // [Finish]
    systems.finish.finish(world, ACCOUNT);

    // [Attack]
    set_contract_address(starknet::contract_address_const::<1>());
    systems.attack.attack(world, ACCOUNT, 0, 0, 0);
}


#[test]
#[available_gas(1_000_000_000)]
#[should_panic(expected: ('Attack: invalid owner', 'ENTRYPOINT_FAILED',))]
fn test_attack_revert_invalid_owner() {
    // [Setup]
    let (world, systems) = setup::spawn_game();
    let mut datastore = DataStoreTrait::new(world);

    // [Create]
    systems.create.create(world, ACCOUNT, SEED, NAME, PLAYER_COUNT);

    // [Compute] Tile army and player available supply
    let game: Game = datastore.game(ACCOUNT);
    let initial_player: Player = datastore.player(game, PLAYER_INDEX);
    let supply: u32 = initial_player.supply.into();
    let mut tile_index: u8 = 1;
    loop {
        let tile: Tile = datastore.tile(game, tile_index);
        if tile.owner == PLAYER_INDEX.into() {
            break;
        }
        tile_index += 1;
    };

    // [Supply]
    systems.supply.supply(world, ACCOUNT, tile_index, supply);

    // [Finish]
    systems.finish.finish(world, ACCOUNT);

    // [Compute] Invalid owned tile
    let game: Game = datastore.game(ACCOUNT);
    let mut index: u8 = 1;
    loop {
        let tile: Tile = datastore.tile(game, index);
        if tile.owner != PLAYER_INDEX.into() {
            break;
        }
        index += 1;
    };

    // [Attack]
    systems.attack.attack(world, ACCOUNT, index, 0, 0);
}
