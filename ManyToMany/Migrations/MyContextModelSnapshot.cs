using System;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;
using ManyToMany;

namespace ManyToMany.Migrations
{
    [DbContext(typeof(MyContext))]
    partial class MyContextModelSnapshot : ModelSnapshot
    {
        protected override void BuildModel(ModelBuilder modelBuilder)
        {
            modelBuilder
                .HasAnnotation("ProductVersion", "1.0.1")
                .HasAnnotation("SqlServer:ValueGenerationStrategy", SqlServerValueGenerationStrategy.IdentityColumn);

            modelBuilder.Entity("ManyToMany.Currency", b =>
                {
                    b.Property<Guid>("UID")
                        .ValueGeneratedOnAdd();

                    b.Property<string>("ISOCode");

                    b.Property<string>("Symbol");

                    b.HasKey("UID");

                    b.HasIndex("ISOCode")
                        .IsUnique()
                        .HasName("UX_Currency_ISOCode");

                    b.ToTable("Currecies");
                });

            modelBuilder.Entity("ManyToMany.Post", b =>
                {
                    b.Property<int>("PostId")
                        .ValueGeneratedOnAdd();

                    b.Property<string>("Content");

                    b.Property<string>("Title");

                    b.HasKey("PostId");

                    b.ToTable("Posts");
                });

            modelBuilder.Entity("ManyToMany.PostTag", b =>
                {
                    b.Property<int>("PostId");

                    b.Property<string>("TagId");

                    b.HasKey("PostId", "TagId");

                    b.HasIndex("PostId");

                    b.HasIndex("TagId");

                    b.ToTable("PostTag");
                });

            modelBuilder.Entity("ManyToMany.Region", b =>
                {
                    b.Property<Guid>("UID")
                        .ValueGeneratedOnAdd();

                    b.Property<string>("CountryISOCode")
                        .HasAnnotation("MaxLength", 8);

                    b.HasKey("UID");

                    b.HasIndex("CountryISOCode")
                        .IsUnique()
                        .HasName("UX_Region_CountryISOCode");

                    b.ToTable("Regions");
                });

            modelBuilder.Entity("ManyToMany.RegionCurrency", b =>
                {
                    b.Property<Guid>("CurrencyUID");

                    b.Property<Guid>("RegionUID");

                    b.HasKey("CurrencyUID", "RegionUID")
                        .HasName("PK_RegionCurrency");

                    b.HasIndex("CurrencyUID");

                    b.HasIndex("RegionUID");

                    b.ToTable("RegionCurrency");
                });

            modelBuilder.Entity("ManyToMany.Tag", b =>
                {
                    b.Property<string>("TagId");

                    b.HasKey("TagId");

                    b.ToTable("Tags");
                });

            modelBuilder.Entity("ManyToMany.PostTag", b =>
                {
                    b.HasOne("ManyToMany.Post", "Post")
                        .WithMany("PostTags")
                        .HasForeignKey("PostId")
                        .OnDelete(DeleteBehavior.Cascade);

                    b.HasOne("ManyToMany.Tag", "Tag")
                        .WithMany("PostTags")
                        .HasForeignKey("TagId")
                        .OnDelete(DeleteBehavior.Cascade);
                });

            modelBuilder.Entity("ManyToMany.RegionCurrency", b =>
                {
                    b.HasOne("ManyToMany.Currency", "Currency")
                        .WithMany("RegionCurrencies")
                        .HasForeignKey("CurrencyUID")
                        .OnDelete(DeleteBehavior.Cascade);

                    b.HasOne("ManyToMany.Region", "Region")
                        .WithMany("RegionCurrencies")
                        .HasForeignKey("RegionUID")
                        .OnDelete(DeleteBehavior.Cascade);
                });
        }
    }
}
