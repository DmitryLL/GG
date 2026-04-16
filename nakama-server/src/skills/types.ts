// Общие типы и интерфейс скиллов.
// Каждый скилл — отдельный файл, регистрируется в registerAllSkills().

interface SkillContext {
    player: MatchPlayer;
    body: any;
    t: number;
    state: WorldState;
    dispatcher: nkruntime.MatchDispatcher;
    baseDmg: number;
}

type SkillHandler = (ctx: SkillContext) => void;

const SKILL_HANDLERS: { [id: number]: SkillHandler } = {};

function registerSkill(id: number, handler: SkillHandler): void {
    SKILL_HANDLERS[id] = handler;
}
