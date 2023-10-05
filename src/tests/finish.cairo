// Core imports

use debug::PrintTrait;

// Starknet imports

use starknet::testing::set_contract_address;

// Dojo imports

use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports

use zrisk::config;
use zrisk::datastore::{DataStore, DataStoreTrait};
use zrisk::components::game::{Game, GameTrait, Turn};
use zrisk::components::player::Player;
use zrisk::components::tile::Tile;
use zrisk::systems::create::ICreateDispatcherTrait;
use zrisk::systems::supply::ISupplyDispatcherTrait;
use zrisk::systems::finish::IFinishDispatcherTrait;
use zrisk::tests::setup::{setup, setup::Systems};

// Constants

const ACCOUNT: felt252 = 'ACCOUNT';
const SEED: felt252 = 'SEED';
const NAME: felt252 = 'NAME';
const PLAYER_COUNT: u8 = 4;
const PLAYER_INDEX: u8 = 0;

#[test]
#[available_gas(1_000_000_000)]
fn test_finish_next_player() {
    // [Setup]
    let (world, systems) = setup::spawn_game();
    let mut datastore = DataStoreTrait::new(world);

    // [Create]
    systems.create.create(world, ACCOUNT, SEED, NAME, PLAYER_COUNT);

    // [Assert] Game
    let game: Game = datastore.game(ACCOUNT);
    assert(game.player() == 0, 'Game: wrong player index 0');
    assert(game.turn() == Turn::Supply, 'Game: wrong turn 0');

    // [Compute] Tile army and player available supply
    let player: Player = datastore.player(game, PLAYER_INDEX);
    let supply: u32 = player.supply.into();
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

    // [Assert] Game
    let game: Game = datastore.game(ACCOUNT);
    assert(game.player() == 0, 'Game: wrong player index 1');
    assert(game.turn() == Turn::Attack, 'Game: wrong turn 1');

    // [Finish]
    systems.finish.finish(world, ACCOUNT);

    // [Assert] Game
    let game: Game = datastore.game(ACCOUNT);
    assert(game.player() == 0, 'Game: wrong player index 2');
    assert(game.turn() == Turn::Transfer, 'Game: wrong turn 2');

    // [Finish]
    systems.finish.finish(world, ACCOUNT);

    // [Assert] Game
    let game: Game = datastore.game(ACCOUNT);
    assert(game.player() == 1, 'Game: wrong player index 3');
    assert(game.turn() == Turn::Supply, 'Game: wrong turn 3');

    // [Assert] Player
    let player: Player = datastore.player(game, game.player());
    assert(player.supply > 0, 'Player: wrong supply');
}

#[test]
#[available_gas(1_000_000_000)]
#[should_panic(expected: ('Finish: invalid supply', 'ENTRYPOINT_FAILED',))]
fn test_finish_revert_invalid_supply() {
    // [Setup]
    let (world, systems) = setup::spawn_game();
    let mut datastore = DataStoreTrait::new(world);

    // [Create]
    systems.create.create(world, ACCOUNT, SEED, NAME, PLAYER_COUNT);

    // [Finish]
    systems.finish.finish(world, ACCOUNT);
}

#[test]
#[available_gas(1_000_000_000)]
#[should_panic(expected: ('Finish: invalid player', 'ENTRYPOINT_FAILED',))]
fn test_finish_revert_invalid_player() {
    // [Setup]
    let (world, systems) = setup::spawn_game();
    let mut datastore = DataStoreTrait::new(world);

    // [Create]
    systems.create.create(world, ACCOUNT, SEED, NAME, PLAYER_COUNT);

    // [Assert] Game
    let game: Game = datastore.game(ACCOUNT);
    assert(game.player() == 0, 'Game: wrong player index 0');
    assert(game.turn() == Turn::Supply, 'Game: wrong turn 0');

    // [Finish]
    set_contract_address(starknet::contract_address_const::<1>());
    systems.finish.finish(world, ACCOUNT);
}
