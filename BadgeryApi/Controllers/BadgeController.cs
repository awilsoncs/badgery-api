using Microsoft.AspNetCore.Mvc;
using BadgeryApi.Models;

namespace BadgeryApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class BadgeController(ILogger<BadgeController> logger) : ControllerBase
{
    private static readonly string[] Summaries =
    [
        "Freezing", "Bracing", "Chilly", "Cool", "Mild", "Warm", 
        "Balmy", "Hot", "Sweltering", "Scorching"
    ];

    private readonly ILogger<BadgeController> _logger = logger;

    [HttpGet(Name = "GetBadge")]
    public IEnumerable<Badge> Get()
    {
        return Enumerable.Range(1, 5).Select(index => new Badge(index)
        {
            Date = DateOnly.FromDateTime(DateTime.Now.AddDays(index)),
            TemperatureC = Random.Shared.Next(-20, 55),
            Summary = Summaries[Random.Shared.Next(Summaries.Length)]
        })
        .ToArray();
    }
}
