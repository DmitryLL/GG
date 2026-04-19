// Общие типы и интерфейс скиллов.
// Каждый скилл — отдельный файл, регистрируется через registerSkill().
// Чтобы поддерживать несколько классов с пересекающимися id (у archer
// skill 1 — РДД-удар, у mage skill 1 — Магическая стрела), держим
// раздельные регистрации: registerSkill() — archer (legacy), а mage
// использует registerMageSkill().

interface SkillContext {
    player: MatchPlayer;
    body: any;
    t: number;
    state: WorldState;
    dispatcher: nkruntime.MatchDispatcher;
    baseDmg: number;
}

interface SkillSpec {
    handler: (ctx: SkillContext) => void;
    requiresBow: boolean;     // если true, без лука скилл не сработает
    cooldownMs: number;       // используется для default; сам handler может ставить свой
}

const SKILLS: { [id: number]: SkillSpec } = {};
const MAGE_SKILLS: { [id: number]: SkillSpec } = {};

function registerSkill(id: number, spec: SkillSpec): void {
    SKILLS[id] = spec;
}
function registerMageSkill(id: number, spec: SkillSpec): void {
    MAGE_SKILLS[id] = spec;
}
// Вернуть таблицу скиллов для класса игрока. Fallback — archer.
function skillsForClass(charClass: string): { [id: number]: SkillSpec } {
    if (charClass === "mage") return MAGE_SKILLS;
    return SKILLS;
}
