using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;

namespace ManyToMany
{
    public class MyContext : DbContext
    {
        public DbSet<Post> Posts { get; set; }
        public DbSet<Tag> Tags { get; set; }

        public DbSet<Currency> Currecies { get; set; }

        public DbSet<RegionCurrency> RegionCurrency { get; set; }

        public DbSet<Region> Regions { get; set; }


        protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
        {

            optionsBuilder.UseSqlServer(@"Server=localhost;Database=ManyToMany;Trusted_Connection=True;");
        }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<PostTag>()
                .HasKey(t => new { t.PostId, t.TagId });

            modelBuilder.Entity<PostTag>()
                .HasOne(pt => pt.Post)
                .WithMany(p => p.PostTags)
                .HasForeignKey(pt => pt.PostId);

            modelBuilder.Entity<PostTag>()
                .HasOne(pt => pt.Tag)
                .WithMany(t => t.PostTags)
                .HasForeignKey(pt => pt.TagId);

            modelBuilder.Entity<RegionCurrency>()
            .HasKey(t => new { t.CurrencyUID, t.RegionUID })
            .HasName("PK_RegionCurrency");

            modelBuilder.Entity<RegionCurrency>()
                .HasOne(pt => pt.Region)
                .WithMany(p => p.RegionCurrencies)
                .HasForeignKey(pt => pt.RegionUID);

            modelBuilder.Entity<RegionCurrency>()
                .HasOne(pt => pt.Currency)
                .WithMany(p => p.RegionCurrencies)
                .HasForeignKey(pt => pt.CurrencyUID);

            modelBuilder.Entity<Currency>()
                .HasIndex(c => c.ISOCode)
                .HasName("UX_Currency_ISOCode")
                .IsUnique();

            modelBuilder.Entity<Region>()
                .HasIndex(c => c.CountryISOCode)
                .HasName("UX_Region_CountryISOCode")
                .IsUnique();
        }
    }

    public class Post
    {
        public int PostId { get; set; }
        public string Title { get; set; }
        public string Content { get; set; }

        public List<PostTag> PostTags { get; set; }
    }

    public class Tag
    {
        public string TagId { get; set; }

        public List<PostTag> PostTags { get; set; }
    }

    public class PostTag
    {
        public int PostId { get; set; }
        public Post Post { get; set; }

        public string TagId { get; set; }
        public Tag Tag { get; set; }
    }

    public class Currency
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public Guid UID { get; set; } = Guid.NewGuid();

        public string ISOCode { get; set; }

        public string Symbol { get; set; }

        public List<RegionCurrency> RegionCurrencies { get; set; }
    }

    public class RegionCurrency
    {
        public Guid CurrencyUID { get; set; }

        public Guid RegionUID { get; set; }

        [ForeignKey("CurrencyUID")]
        public Currency Currency { get; set; }

        [ForeignKey("RegionUID")]
        public Region Region { get; set; }
    }

    public class Region
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public Guid UID { get; set; } = Guid.NewGuid();

        [StringLength(8)]
        public string CountryISOCode { get; set; }

        public List<RegionCurrency> RegionCurrencies { get; set; }
    }
}
