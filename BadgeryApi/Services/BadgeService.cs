using BadgeryApi.Models;

namespace BadgeryApi.Services;

public static class BadgeService {

    static List<Badge> Badges { get; }
    static int _nextId = 2;

    static BadgeService() {
        Badges = [
            new Badge(0),
            new Badge(1)
        ];
    }

    public static List<Badge> GetAll() => Badges;

    public static Badge? Get(int id) => Badges.FirstOrDefault((b) => b.Id == id);

    public static void Add(Badge badge) {
        badge.Id = _nextId++;
        Badges.Add(badge);
    }

    public static void Update(Badge badge) {
        int index = Badges.FindIndex(b => b.Id == badge.Id);
        if (index == -1) {
            return;
        }
        Badges[index] = badge;
    }

    public static void Delete(int id) {
        Badge? badge = Badges.FirstOrDefault(b => b.Id == id);
        if (badge == null) {
            return;
        }
    }
}