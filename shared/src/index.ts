export const MAP_WIDTH = 800;
export const MAP_HEIGHT = 600;
export const MAX_STEP_PER_TICK = 16;
export const PLAYER_SPEED = 200;

export const ROOM_NAME = "game_room";

export type MoveMessage = { x: number; y: number };

export type ClientMessages = {
  move: MoveMessage;
};

export type JoinOptions = {
  token?: string;
};

export type PlayerView = {
  x: number;
  y: number;
};
