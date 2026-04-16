// Общие типы и интерфейс скиллов.
// Каждый скилл — отдельный файл, регистрируется через registerSkill().

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

function registerSkill(id: number, spec: SkillSpec): void {
    SKILLS[id] = spec;
}
