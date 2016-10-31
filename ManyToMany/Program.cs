using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;

namespace ManyToMany
{
    class Program
    {
        static void Main(string[] args)
        {
            using (var db = new MyContext())
            {
                //var tag = db.Tags.Include(t => t.PostTags)
                //                 .ThenInclude(p => p.Post)
                //                 .FirstOrDefault(t => t.TagId  == "2");

                //var posts = tag.PostTags.Select(c => c.Post).ToList();

                var currency = db.Currecies.Include(t => t.RegionCurrencies)
                                    .ThenInclude(p => p.Region)
                                    .FirstOrDefault(t => t.UID == Guid.Parse("0f8fad5b-d9cb-469f-a165-70867728950e"));

                var regions = currency.RegionCurrencies.Select(c => c.Region).ToList();

            }
        }
    }
}
