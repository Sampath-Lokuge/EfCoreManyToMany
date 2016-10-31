using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore.Migrations;

namespace ManyToMany.Migrations
{
    public partial class RegionCurrency : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Currecies",
                columns: table => new
                {
                    UID = table.Column<Guid>(nullable: false),
                    ISOCode = table.Column<string>(nullable: true),
                    Symbol = table.Column<string>(nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Currecies", x => x.UID);
                });

            migrationBuilder.CreateTable(
                name: "Regions",
                columns: table => new
                {
                    UID = table.Column<Guid>(nullable: false),
                    CountryISOCode = table.Column<string>(maxLength: 8, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Regions", x => x.UID);
                });

            migrationBuilder.CreateTable(
                name: "RegionCurrency",
                columns: table => new
                {
                    CurrencyUID = table.Column<Guid>(nullable: false),
                    RegionUID = table.Column<Guid>(nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RegionCurrency", x => new { x.CurrencyUID, x.RegionUID });
                    table.ForeignKey(
                        name: "FK_RegionCurrency_Currecies_CurrencyUID",
                        column: x => x.CurrencyUID,
                        principalTable: "Currecies",
                        principalColumn: "UID",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_RegionCurrency_Regions_RegionUID",
                        column: x => x.RegionUID,
                        principalTable: "Regions",
                        principalColumn: "UID",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "UX_Currency_ISOCode",
                table: "Currecies",
                column: "ISOCode",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "UX_Region_CountryISOCode",
                table: "Regions",
                column: "CountryISOCode",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_RegionCurrency_CurrencyUID",
                table: "RegionCurrency",
                column: "CurrencyUID");

            migrationBuilder.CreateIndex(
                name: "IX_RegionCurrency_RegionUID",
                table: "RegionCurrency",
                column: "RegionUID");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "RegionCurrency");

            migrationBuilder.DropTable(
                name: "Currecies");

            migrationBuilder.DropTable(
                name: "Regions");
        }
    }
}
